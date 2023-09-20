// const { expect } = require("chai");
const chai = require("chai");
const { expect } = chai;

import {
    mine,
    mineUpTo,
    time,
    setBalance,
    reset,
    SnapshotRestorer,
    takeSnapshot,
} from "@nomicfoundation/hardhat-network-helpers";
import { JsonRpcSigner } from "ethers";
import hre from "hardhat";

const {
    ethers,
    deployments,
    deployments: { createFixture },
} = hre;

import { GovernorAlpha, IStaking, LiquityBaseParams, SOV, StakingProxy } from "types/generated";

const MAX_DURATION = BigInt(24 * 60 * 60 * 1092);
const ONE_RBTC = ethers.parseEther("1.0");

const getImpersonatedSignerFromJsonRpcProvider = async (addressToImpersonate) => {
    const provider = new ethers.JsonRpcProvider("http://localhost:8545");
    await provider.send("hardhat_impersonateAccount", [addressToImpersonate]);
    return provider.getSigner(addressToImpersonate);
};

describe("SIP-0066 onchain test", () => {
    const setupTest = createFixture(async ({ deployments, getNamedAccounts }) => {
        const { deployer } = await getNamedAccounts();

        const deployerSigner = await ethers.getSigner(deployer);
        await setBalance(deployer, ONE_RBTC * 10n);
        /*await deployments.fixture(["StakingModules", "StakingModulesProxy"], {
            keepExistingDeployments: true,
        }); // start from a fresh deployments
        */
        const stakingProxy = (await ethers.getContract("StakingProxy", deployer)) as StakingProxy;
        const stakingModulesProxy = await ethers.getContract("StakingModulesProxy", deployer);

        const god = await deployments.get("GovernorOwner");
        const governorOwner = (await ethers.getContract("GovernorOwner")) as GovernorAlpha;
        /*const governorOwner = await ethers.getContractAt(
            "GovernorAlpha",
            god.address,
            deployerSigner
        );*/
        const governorOwnerSigner: JsonRpcSigner = (await getImpersonatedSignerFromJsonRpcProvider(
            god.address
        )) as JsonRpcSigner;

        await setBalance(governorOwnerSigner.address, ONE_RBTC);
        const timelockOwner = await ethers.getContract("TimelockOwner", governorOwnerSigner);

        const timelockOwnerSigner: JsonRpcSigner = (await getImpersonatedSignerFromJsonRpcProvider(
            timelockOwner.target
        )) as JsonRpcSigner;
        await setBalance(timelockOwnerSigner.address, ONE_RBTC);

        const multisigSigner: JsonRpcSigner = (await getImpersonatedSignerFromJsonRpcProvider(
            (
                await deployments.get("MultiSigWallet")
            ).address
        )) as JsonRpcSigner;
        //
        return {
            deployer,
            deployerSigner,
            stakingProxy,
            stakingModulesProxy,
            governorOwner,
            governorOwnerSigner,
            timelockOwner,
            timelockOwnerSigner,
            multisigSigner,
        };
    });

    let snapshot: SnapshotRestorer;
    before(async () => {
        await reset("https://mainnet-dev.sovryn.app/rpc", 5505345);
        snapshot = await takeSnapshot();
    });
    async () => {
        await snapshot.restore();
    };

    it("SIP-0066 is executable", async () => {
        if (!hre.network.tags["forked"]) return;
        const {
            deployer,
            deployerSigner,
            stakingProxy,
            governorOwner,
            timelockOwnerSigner,
            multisigSigner,
        } = await setupTest();
        // loadFixtureAfterEach = true;
        // CREATE PROPOSAL
        const sov = (await ethers.getContract("SOV", timelockOwnerSigner)) as SOV;
        const whaleAmount = (await sov.totalSupply()) * BigInt(5);
        await sov.mint(deployerSigner.address, whaleAmount);

        /*
            const quorumVotes = await governorOwner.quorumVotes();
            console.log('quorumVotes:', quorumVotes);
            */
        await sov.connect(deployerSigner).approve(stakingProxy.target, whaleAmount);
        //const stakeABI = (await hre.artifacts.readArtifact("IStaking")).abi;
        const stakeABI = (await deployments.getArtifact("IStaking")).abi;
        // const stakeABI = (await ethers.getContractFactory("IStaking")).interface;
        // alternatively for stakeABI can be used human readable ABI:
        /*const stakeABI = [
                'function stake(uint96 amount,uint256 until,address stakeFor,address delegatee)',
                'function pauseUnpause(bool _pause)',
                'function paused() view returns (bool)'
            ];*/
        const staking = (await ethers.getContractAt(
            stakeABI,
            stakingProxy.target,
            deployerSigner
        )) as unknown as IStaking;
        /*const multisigSigner = await getImpersonatedSignerFromJsonRpcProvider(
                (
                    await get("MultiSigWallet")
                ).address
            );*/
        if (await staking.paused()) await staking.connect(multisigSigner).pauseUnpause(false);
        const kickoffTS = await stakingProxy.kickoffTS();
        await staking.stake(whaleAmount, kickoffTS + MAX_DURATION, deployer, deployer);
        await mine();

        // CREATE PROPOSAL AND VERIFY
        const proposalIdBeforeSIP = Number(await governorOwner.latestProposalIds(deployer));
        await hre.run("sips:create", { argsFunc: "zeroFeesUpdateSip0066" });
        const proposalId = Number(await governorOwner.latestProposalIds(deployer));
        expect(
            proposalId,
            "Proposal was not created. Check the SIP creation is not commented out."
        ).equals(proposalIdBeforeSIP + 1);

        // VOTE FOR PROPOSAL
        console.log("voting for proposal");
        await mine();
        await governorOwner.connect(deployerSigner).castVote(proposalId, true);

        // QUEUE PROPOSAL
        let proposal = await governorOwner.proposals(proposalId);

        await mineUpTo(proposal.endBlock);
        await mine();

        await governorOwner.queue(proposalId);

        // EXECUTE PROPOSAL
        proposal = await governorOwner.proposals(proposalId);
        await time.increaseTo(proposal.eta);
        await expect(governorOwner.execute(proposalId))
            .to.emit(governorOwner, "ProposalExecuted")
            .withArgs(proposalId);

        // VALIDATE EXECUTION
        expect((await governorOwner.proposals(proposalId)).executed).to.be.true;

        const zeroBaseParams: LiquityBaseParams = <LiquityBaseParams>(
            (<unknown>await ethers.getContract("LiquityBaseParams"))
        );
        const newBorrowingFeeFloor = ethers.parseEther("0.99");
        const newMaxBorrowingFee = ethers.parseEther("1.00");

        expect(await zeroBaseParams.BORROWING_FEE_FLOOR()).to.equal(newBorrowingFeeFloor);
        expect(await zeroBaseParams.MAX_BORROWING_FEE()).to.equal(newMaxBorrowingFee);
    });
});
