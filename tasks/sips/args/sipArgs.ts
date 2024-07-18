import { HardhatRuntimeEnvironment } from "hardhat/types";
import Logs from "node-logs";
import { TroveManager } from "types/generated";
const logger = new Logs().showInConsole(true);

export interface ISipArgument {
    args: {
        targets: string[];
        values: number[];
        signatures: string[];
        data: string[];
        description: string;
    };
    governor: string;
}

const zeroMyntIntegrationSIP = async (hre: HardhatRuntimeEnvironment): Promise<ISipArgument> => {
    const {
        ethers,
        deployments: { get },
    } = hre;

    const targetContractsList = [
        "BorrowerOperations",
        "StabilityPool",
        "ZUSDToken",
        "TroveManager",
    ];
    const targetsContractProxies = await Promise.all(
        targetContractsList.map(async (val) => {
            return (await get(val)).address;
        })
    );

    const contractsImplementations = await Promise.all(
        targetContractsList.map(async (val) => {
            return (await get(val + "_Implementation")).address;
        })
    );

    const getImplementationAbi = ["function getImplementation() public view returns(address)"];
    // const getImplementationInterface = new ethers.Interface(getImplementationAbi);
    // validate deployments
    const errorLog: string[] = [];
    await Promise.all(
        targetsContractProxies.map(async (val, index) => {
            const proxy = await ethers.getContractAt(getImplementationAbi, val);
            if ((await proxy.getImplementation()) === contractsImplementations[index]) {
                errorLog.push(
                    `Implementation ${targetContractsList[index]} has not changed: ${contractsImplementations[index]}`
                );
            }
        })
    );
    if (errorLog.length > 0) {
        logger.error(errorLog);
        //throw Error();
    }

    const iSetImplementationInterface = new ethers.Interface([
        "function setImplementation(address _implementation)",
    ]);

    const datas = targetsContractProxies.map((val, index) => {
        return iSetImplementationInterface
            .getAbiCoder()
            .encode(["address"], [contractsImplementations[index]]);
    });
    const signatures = Array(targetsContractProxies.length).fill("setImplementation(address)");

    // replace troveManagerRedeepOps in TroveManager
    const iSetTroveManagerRedeemOps = new ethers.Interface([
        "function setTroveManagerRedeemOps(address _troveManagerRedeemOps)",
    ]);

    signatures.push("setTroveManagerRedeemOps(address)");
    const troveManagerDeployment = await get("TroveManager");
    const troveManagerRedeemOpsDeployment = await get("TroveManagerRedeemOps");
    targetsContractProxies.push(troveManagerDeployment.address);
    datas.push(
        iSetTroveManagerRedeemOps
            .getAbiCoder()
            .encode(["address"], [troveManagerRedeemOpsDeployment.address])
    );

    // validate TroveManagerRedeemOps
    const troveManager = (await ethers.getContract("TroveManager")) as unknown as TroveManager;
    if ((await troveManager.troveManagerRedeemOps()) === troveManagerRedeemOpsDeployment.address) {
        logger.error(
            `TroveManagerRedeemOps is not changed: ${troveManagerRedeemOpsDeployment.address}. Either deployment address is wrong or should be excluded from the SIP.`
        );
        throw Error();
    }

    // set MassetManager address in BorrowerOperations
    const iSetMassetManagerAddress = new ethers.Interface([
        "function setMassetManagerAddress(address _massetManagerAddress)",
    ]);
    signatures.push("setMassetManagerAddress(address)");
    const borrowerOperations = await ethers.getContract("BorrowerOperations");
    targetsContractProxies.push(borrowerOperations.target.toString());
    const massetManagerDeployment = await get("MassetManager");
    datas.push(
        iSetMassetManagerAddress
            .getAbiCoder()
            .encode(["address"], [massetManagerDeployment.address])
    );

    /*
    there is no IMassetManager yet
    if (
        ethers.getAddress(await borrowerOperations.massetManager()) ===
        massetManagerDeployment.address
    ) {
        logger.error(
            `MassetManager is not changed: ${troveManagerRedeemOpsDeployment.address}. Either deployment address is wrong or should be excluded from the SIP.`
        );
        throw Error();
    }*/

    const args: ISipArgument = {
        args: {
            targets: targetsContractProxies,
            values: Array(targetsContractProxies.length).fill(0),
            signatures: signatures,
            data: datas,
            description:
                "SIP-0054: Integrate Mynt with Zero, Details: https://github.com/DistributedCollective/SIPS/blob/98ef848/SIP-0054.md, sha256: f623ab973a6fa175cc2bd1ebc50cf79699de2f88b84d98535288dba150a4ff4b",
        },
        governor: "GovernorOwner",
    };

    return args;
};

const zeroFeesUpdate = async (hre: HardhatRuntimeEnvironment): Promise<ISipArgument> => {
    const {
        ethers,
        deployments: { get },
    } = hre;
    const zeroBaseParams = await get("LiquityBaseParams");
    const newFeeValue = ethers.parseEther("0.025");
    const iSetFeesFloor = new ethers.Interface([
        "function setBorrowingFeeFloor(uint256)",
        "function setRedemptionFeeFloor(uint256)",
    ]);
    const args: ISipArgument = {
        args: {
            targets: [zeroBaseParams.address, zeroBaseParams.address],
            values: [0, 0],
            signatures: ["setBorrowingFeeFloor(uint256)", "setRedemptionFeeFloor(uint256)"],
            data: [
                iSetFeesFloor.getAbiCoder().encode(["uint256"], [newFeeValue]),
                iSetFeesFloor.getAbiCoder().encode(["uint256"], [newFeeValue]),
            ],
            description:
                "SIP-0055: Zero Fee Floor Update, Details: https://github.com/DistributedCollective/SIPS/blob/b7efe43/SIP-0055.md, sha256: 0f193ed8589e8ef0e8db3b66ef2c23a6b139245d3a9335b67851421cbd73d53c",
        },
        governor: "GovernorOwner",
    };

    return args;
};

const sip0054And0055Combo = async (hre: HardhatRuntimeEnvironment): Promise<ISipArgument> => {
    const args0054: ISipArgument = await zeroMyntIntegrationSIP(hre);
    const args0055: ISipArgument = await zeroFeesUpdate(hre);
    let argsCombo: ISipArgument = {
        args: {
            targets: [],
            values: [],
            signatures: [],
            data: [],
            description: "",
        },
        governor: "GovernorOwner",
    };
    for (const prop in args0054.args) {
        argsCombo.args[prop] =
            prop !== "description"
                ? args0054.args[prop].concat(args0055.args[prop])
                : `Unified SIP-0054 and SIP-0055. ${args0054.args[prop]}. ${args0055.args[prop]}`;
    }
    return argsCombo;
};

const sip0061 = async (hre: HardhatRuntimeEnvironment): Promise<ISipArgument> => {
    const {
        ethers,
        deployments: { get },
    } = hre;

    // @todo for the mainnet deployment first run `yarn deploy --tags 'StabilityPool,CommunityIssuance' --network rskSovrynMainnet`
    const newStabilityPoolImplementation = (await get("StabilityPool_Implementation")).address;

    const communityIssuanceAddress = (await get("CommunityIssuance_Proxy")).address;

    console.log(`New stability pool implementation: ${newStabilityPoolImplementation}`);
    console.log(`Community issuance address: ${communityIssuanceAddress}`);

    const stabilityPoolProxyAddress = (await get("StabilityPool_Proxy")).address;

    const args: ISipArgument = {
        args: {
            targets: [stabilityPoolProxyAddress, stabilityPoolProxyAddress],
            values: [0, 0],
            signatures: ["setImplementation(address)", "setCommunityIssuanceAddress(address)"],
            data: [
                ethers.AbiCoder.defaultAbiCoder().encode(
                    ["address"],
                    [newStabilityPoolImplementation]
                ),
                ethers.AbiCoder.defaultAbiCoder().encode(["address"], [communityIssuanceAddress]),
            ],
            description:
                "SIP-0061: Zero stability pool subsidies: https://github.com/DistributedCollective/SIPS/blob/cc1a368/SIP-0061.md, sha256: 9c38bb9e30855ef7fc2fba8a3a6b731182577ed8f5d5f5b18773ca528bde532b",
        },
        governor: "GovernorOwner",
    };

    return args;
};

const zeroFeesUpdateSip0059 = async (hre: HardhatRuntimeEnvironment): Promise<ISipArgument> => {
    const {
        ethers,
        deployments: { get },
    } = hre;
    const zeroBaseParams = await get("LiquityBaseParams");
    const newBorrowingFeeFloorValue = ethers.parseEther("0.05");
    const newMaxBorrowingFee = ethers.parseEther("0.075");
    const newRedemptionFeeFloor = ethers.parseEther("0.019");
    const iSetFeesFloor = new ethers.Interface([
        "function setBorrowingFeeFloor(uint256)",
        "function setMaxBorrowingFee(uint256)",
        "function setRedemptionFeeFloor(uint256)",
    ]);
    const args: ISipArgument = {
        args: {
            targets: [zeroBaseParams.address, zeroBaseParams.address, zeroBaseParams.address],
            values: [0, 0, 0],
            signatures: [
                "setBorrowingFeeFloor(uint256)",
                "setMaxBorrowingFee(uint256)",
                "setRedemptionFeeFloor(uint256)",
            ],
            data: [
                iSetFeesFloor.getAbiCoder().encode(["uint256"], [newBorrowingFeeFloorValue]),
                iSetFeesFloor.getAbiCoder().encode(["uint256"], [newMaxBorrowingFee]),
                iSetFeesFloor.getAbiCoder().encode(["uint256"], [newRedemptionFeeFloor]),
            ],
            description:
                "SIP-0059: Zero Fee Floor Update: March 22, Details: https://github.com/DistributedCollective/SIPS/blob/b22933f/SIP-0059.md, sha256: cf432a01b302b0c21b35f55c423d36233cf2f536a96a4d6cc97b2c5b5bb1fbda",
        },
        governor: "GovernorOwner",
    };

    return args;
};

const sip0062 = async (hre: HardhatRuntimeEnvironment): Promise<ISipArgument> => {
    // Updating REDEMPTION_FEE_FLOOR from 1.9% to 1%
    const {
        ethers,
        deployments: { get },
    } = hre;
    const zeroBaseParams = await get("LiquityBaseParams");
    const newRedemptionFeeFloor = ethers.parseEther("0.01");
    const iSetFeesFloor = new ethers.Interface(["function setRedemptionFeeFloor(uint256)"]);
    const args: ISipArgument = {
        args: {
            targets: [zeroBaseParams.address],
            values: [0],
            signatures: ["setRedemptionFeeFloor(uint256)"],
            data: [iSetFeesFloor.getAbiCoder().encode(["uint256"], [newRedemptionFeeFloor])],
            description:
                "SIP-0062: Zero Fee Floor Update, May 12, Details: https://github.com/DistributedCollective/SIPS/blob/4fed4b8/SIP-0062.md, sha256: 566e57c2e98c848395b1b6b2d3718175ed592014a33e81c305947e5017b5925e",
        },
        governor: "GovernorOwner",
    };

    return args;
};

const zeroFeesUpdateSip0066 = async (hre: HardhatRuntimeEnvironment): Promise<ISipArgument> => {
    const {
        ethers,
        deployments: { get },
    } = hre;
    const zeroBaseParams = await get("LiquityBaseParams");
    const newBorrowingFeeFloorValue = ethers.parseEther("0.99");
    const newMaxBorrowingFee = ethers.parseEther("1.00");
    const args: ISipArgument = {
        args: {
            targets: [zeroBaseParams.address, zeroBaseParams.address],
            values: [0, 0],
            signatures: ["setBorrowingFeeFloor(uint256)", "setMaxBorrowingFee(uint256)"],
            data: [
                ethers.AbiCoder.defaultAbiCoder().encode(["uint256"], [newBorrowingFeeFloorValue]),
                ethers.AbiCoder.defaultAbiCoder().encode(["uint256"], [newMaxBorrowingFee]),
            ],
            description:
                "SIP-0066: Curtailing Zero borrowing, Details: https://github.com/DistributedCollective/SIPS/blob/54fe297/SIP-0066.md, sha256: b6aacd47eb5121f4b3c0c835157d3963e4c75354ee008ba717621a32bf9fa745",
        },
        governor: "GovernorOwner",
    };

    return args;
};


const sip0071 = async (hre: HardhatRuntimeEnvironment): Promise<ISipArgument> => {
    const { ethers, deployments } = hre;

    const zeroBaseParamsContract = await deployments.get("LiquityBaseParams");
    const newBorrowingFeeFloor = ethers.parseEther("0.13");
    const encodedNewBorrowingFeeFloor = ethers.AbiCoder.defaultAbiCoder().encode(
        ["uint256"],
        [newBorrowingFeeFloor]
    );
    const title = "SIP-0071: Free Zero, Free Markets, Free Individuals";
    const link =
        "https://forum.sovryn.com/t/sip-0071-free-zero-free-markets-free-individuals/3054";
    const summary = "Reopen ZUSD minting in Zero protocol with a 13% origination fee floor.";
    const text = `
    ## Summary

    If approved, this Proposal will reopen ZUSD minting in Zero protocol with a 13% origination fee floor.
    The goal is to bring back a functional two-sided market,
    restore user confidence in the system, and generate more revenue for Bitocracy stakers.

    ## Background

    Four months ago, the origination fee floor of Zero Protocol was raised to 99% with SIP-0066.
    Essentially, Bitocracy paused the minting of ZUSD to maintain the DLLR peg
    and minimize ZUSD redemptions.
    During that four-month time period, several key observations were made:

    - The total supply of ZUSD decreased from approximately 6.69 million to 4.58 million.
    - Approximately 1 million ZUSD redemptions took place.
    - Around 1.08 million ZUSD credit repayments were made.
    - The total collateral ratio increased from around 372% to 530%.
    - The 90-day moving average daily revenue dropped from 0.03667 BTC to 0.00938 BTC, 
      a reduction of approximately 74.4%.

    ## Motivation

    We see that the demand and supply market of ZUSD has reached an equilibrium point. 
    There were only around 50K ZUSD redemptions that took place in November. 
    The excess ZUSD supply has been removed. 
    The current 14% interest rate of DLLR also indicates strong demand. 
    Therefore, it is a solid time to restore a functional two-sided market where 
    individuals can take the trade of minting new ZUSD with the risk of getting redeemed.

    All Defi Protocols are confidence games.
    Bitocracy is a private entity that issues private currencies backed by BTC. 
    Therefore, it is important to consider public optics and
    present the platform as reliable and trustworthy.

    Reopening ZUSD minting will generate more revenue for Bitocracy stakers. 
    The market will revalue the SOV token to a higher price. 
    With high transaction fees in the Bitcoin network and upcoming halving,
    the price signal of the SOV token will be the best marketing to bring new users to the Sovryn platform.

    ## Why 13%

    The number we have chosen is close to the current interest rate of DLLR
    but not too high that speculators won't pay. 
    The number should be lower than the interest rate of DLLR simply
    because minting ZUSD requires more collateral (average 560%)
    to maintain without significant redemption risk.

    The number is derived from the golden ratio.
    5 \* 1.618^2 = 13.08962

    The 13% fee will significantly restrict the growth of the ZUSD supply
    but not be too high to stop the growth completely.

    ## Proposed changes

    If approved, the origination fee will fluctuate between 13% and 100%.
    The following change will be made to the Zero Protocol base parameters:

    - Updating "BORROWING_FEE_FLOOR" from 99% to 13% by calling \`setBorrowingFeeFloor(uint256)\` 
      on the \`0xf8B04A36c36d5DbD1a9Fe7B74897c609d6A17aa2\` contract
      with the encoded data \`0x00000000000000000000000000000000000000000000000001cdda4faccd0000\`.

    ## License

    Copyright and related rights waived via [CC0](https://creativecommons.org/publicdomain/zero/1.0/).
    `;
    const description: string = `${title}\n${link}\n${summary}\n---\n${text}`;
    return {
        args: {
            targets: [zeroBaseParamsContract.address],
            values: [0],
            signatures: ["setBorrowingFeeFloor(uint256)"],
            data: [encodedNewBorrowingFeeFloor],
            description: description,
        },
        governor: "GovernorOwner",
    };
};

const sip0075 = async (hre: HardhatRuntimeEnvironment): Promise<ISipArgument> => {
    const { ethers, deployments } = hre;

    const zeroBaseParamsContract = await deployments.get("LiquityBaseParams");
    const newBorrowingFeeFloor = ethers.parseEther("0.08");
    const encodedNewBorrowingFeeFloor = ethers.AbiCoder.defaultAbiCoder().encode(
        ["uint256"],
        [newBorrowingFeeFloor]
    );
    const title = "SIP-0075: Reduce Zero Origination Fee";
    const link = "https://forum.sovryn.com/t/sip-0075-reduce-zero-origination-fee";
    const summary = "Reduce Zero Origination Fee Floor to 8%";
    const text = `
    ## Summary

    If approved, this proposal will reduce ZUSD origination fee floor in the Sovryn Zero protocol from 13% to 8%.

    ## Background

    Six months ago, the origination fee floor of Zero Protocol was raised to 99% with SIP-0066.
    Essentially, Bitocracy paused the minting of ZUSD by setting extremely high fees to maintain the DLLR peg.
    Two months ago, Zero was "reopened" by setting the origination fee to 13% with SIP-0071. This fee was deliberately set quite high in order to cautiously ramp up the system again and achieve the assumed balance between supply and demand for $DLLR.

    Since then several key observations were made:
    • The total supply of ZUSD decreased from approximately 6.69 million (start SIP-0066) to 4.58 million (start SIP-0071) to 3.85 million (now).
    • Numbers of LoC’s declined from 150 (start SIP-0066) to 88 (start SIP-0071) to 83 (now).
    • The total collateral ratio increased from around 372% (SIP-0066) to 530% (SIP-0071) to 604% (now).
    • From SIP-0066 to SIP-0071 (8/23-12/23), Zero fee revenue was 15k USD. Since SIP-0071 (01/24) (total Zero fee revenue is 34k USD).

    ## Motivation

    Despite reopening Zero, we can still see a decline in the metrics shown above.
    Large parts of the excess ZUSD supply has been removed.
    The current 10% interest rate of DLLR lending pool also indicates strong demand.
    Therefore, we believe it is a good time to make Zero more accessible and to increase protocol revenue.
    Individual users should make sure they understand the system and specifically, redemptions.
    If significantly more redemptions occur than expected, Sovryn can also use the increased revenue as a safety mechanism to incentivize the holding of $DLLR via $SOV rewards.

    ## Proposed changes

    If approved, the origination fee will fluctuate between 8% and 100%.
    The following change will be made to the Zero Protocol base parameters:

    - Updating "BORROWING_FEE_FLOOR" from 13% to 8% by calling \`setBorrowingFeeFloor(uint256)\`
    on the \`0xf8B04A36c36d5DbD1a9Fe7B74897c609d6A17aa2\` contract
    with the encoded data \`0x000000000000000000000000000000000000000000000000011c37937e080000\`.

    ## License

    Copyright and related rights waived via [CC0](https://creativecommons.org/publicdomain/zero/1.0/).
    `;
    const description: string = `${title}\n${link}\n${summary}\n---\n${text}`;
    return {
        args: {
            targets: [zeroBaseParamsContract.address],
            values: [0],
            signatures: ["setBorrowingFeeFloor(uint256)"],
            data: [encodedNewBorrowingFeeFloor],
            description: description,
        },
        governor: "GovernorOwner",
    };
};

const sipSOV3564 = async (hre: HardhatRuntimeEnvironment): Promise<ISipArgument> => {
    const {
        ethers,
        deployments: { get },
    } = hre;

    // @todo for the mainnet deployment first run `yarn deploy --tags 'StabilityPool,BorrowerOperations,TroveManager' --network rskSovrynMainnet`
    const newStabilityPoolImplementation = (await get("StabilityPool_Implementation")).address;
    const newBorrowerOperationsImplementation = (await get("BorrowerOperations_Implementation")).address;
    const newTroveManagerImplementation = (await get("TroveManager_Implementation")).address;

    console.log(`New stability pool implementation: ${newStabilityPoolImplementation}`);
    console.log(`New borrower operations implementation: ${newBorrowerOperationsImplementation}`);
    console.log(`New trove manager implementation: ${newTroveManagerImplementation}`);

    const stabilityPoolProxyDeployment = await get("StabilityPool_Proxy");
    const borrowerOperationsDeployment = await get("BorrowerOperations_Proxy");
    const troveManagerDeployment = await get("TroveManager_Proxy");
    const troveManagerRedeemOpsDeployment = await get("TroveManagerRedeemOps");


    const errorLog: string[] = [];
    const stabilityPoolProxy = await ethers.getContractAt(stabilityPoolProxyDeployment.abi, stabilityPoolProxyDeployment.address);
    if ((await stabilityPoolProxy.getImplementation()) === newStabilityPoolImplementation) {
        errorLog.push(
            `Implementation StabilityPool has not changed: ${newStabilityPoolImplementation}`
        );
    }

    const borrrowerOperationsProxy = await ethers.getContractAt(borrowerOperationsDeployment.abi, borrowerOperationsDeployment.address);
    if ((await borrrowerOperationsProxy.getImplementation()) === newBorrowerOperationsImplementation) {
        errorLog.push(
            `Implementation BorrowerOperations has not changed: ${newBorrowerOperationsImplementation}`
        );
    }

    const troveManagerPoxy = await ethers.getContractAt(troveManagerDeployment.abi, troveManagerDeployment.address);
    if ((await troveManagerPoxy.getImplementation()) === newTroveManagerImplementation) {
        errorLog.push(
            `Implementation TroveManager has not changed: ${newTroveManagerImplementation}`
        );
    }

    if (errorLog.length > 0) {
        logger.error(errorLog);
        throw Error("^");
    }

    const args: ISipArgument = {
        args: {
            targets: [stabilityPoolProxyDeployment.address, borrowerOperationsDeployment.address, troveManagerDeployment.address, troveManagerDeployment.address],
            values: [0, 0, 0, 0],
            signatures: ["setImplementation(address)", "setImplementation(address)", "setImplementation(address)", "setTroveManagerRedeemOps(address)"],
            data: [
                ethers.AbiCoder.defaultAbiCoder().encode(
                    ["address"],
                    [newStabilityPoolImplementation]
                ),
                ethers.AbiCoder.defaultAbiCoder().encode(["address"], [newBorrowerOperationsImplementation]),
                ethers.AbiCoder.defaultAbiCoder().encode(["address"], [newTroveManagerImplementation]),
                ethers.AbiCoder.defaultAbiCoder().encode(["address"], [troveManagerRedeemOpsDeployment.address]),
            ],
            // @todo update sip description
            description:
                "SIP-SOV3564: upgrade stabilityPool, borrowerOperations, troveManager, setTroveManagerRedeemOps",
        },
        governor: "GovernorOwner",
    };

    return args;
};

const sip0082 = async (hre: HardhatRuntimeEnvironment): Promise<ISipArgument> => {
    const { ethers, deployments } = hre;

    const zeroBaseParamsContract = await deployments.get("LiquityBaseParams");
    const newBorrowingFeeFloor = ethers.parseEther("0.05");
    const encodedNewBorrowingFeeFloor = ethers.AbiCoder.defaultAbiCoder().encode(
        ["uint256"],
        [newBorrowingFeeFloor]
    );
    const title = "SIP-0082: Reduce Zero Origination Fee Floor to 5%";
    const link = "https://forum.sovryn.com/t/sip-0082-reduce-zero-origination-fee-floor-to-5";
    const summary = "Reduce Zero Origination Fee Floor from 8% to 5%";
    const text = `
    ## Summary

    If approved, this proposal will reduce the ZUSD origination fee floor in the Sovryn Zero protocol from 8% to 5%.

    ## Motivation

    The Zero Protocol is still in the bootstrap period. We should focus on growing the ZUSD/DLLR supply. The 2% to 5% redemption percentage per month is generally acceptable. For the past 30 days, there were about 7.2 BTC redemptions (~1.3%), even with fairly volatile BTC price movement. The level of redemption is generally low. Given incoming liquidity easing, the condition is perfect for reducing the origination fee. With a lower origination fee, we will likely see an increase in ZUSD supply and protocol revenue.

    ## Proposed Changes

    If approved, the origination fee will fluctuate between 5% and 100%. The following change will be made to the Zero Protocol base parameters:

    It will update "BORROWING_FEE_FLOOR" from 8% to 5% by calling \`setBorrowingFeeFloor(uint256)\` on the \`0xf8B04A36c36d5DbD1a9Fe7B74897c609d6A17aa2\` contract with the encoded data \`0x00000000000000000000000000000000000000000000000000b1a2bc2ec50000\`.

    ## License

    Copyright and related rights waived via [CC0](https://creativecommons.org/publicdomain/zero/1.0/).
    `;

    const description: string = `${title}\n${link}\n${summary}\n---\n${text}`;
    return {
        args: {
            targets: [zeroBaseParamsContract.address],
            values: [0],
            signatures: ["setBorrowingFeeFloor(uint256)"],
            data: [encodedNewBorrowingFeeFloor],
            description: description,
        },
        governor: "GovernorOwner",
    };
};

const sipArgs = {
    zeroMyntIntegrationSIP,
    zeroFeesUpdate,
    sip0054And0055Combo,
    sip0061,
    zeroFeesUpdateSip0059,
    sip0062,
    zeroFeesUpdateSip0066,
    sip0071,
    sip0075,
    sipSOV3564,
    sip0082,
};

export default sipArgs;
