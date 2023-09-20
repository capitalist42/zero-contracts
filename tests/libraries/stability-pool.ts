/* eslint-disable no-unused-expressions */
/* eslint-disable camelcase */
/* eslint-disable node/no-missing-import */

/* @todo remove when the libraries tests transitioned to Foundry 

import { TestLibraries } from "../../types/generated";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { TestLibraries__factory } from "../../types/generated";
import { StabilityPool } from "../../types/generated";
import { ethers } from "hardhat";
import chai from "chai";
import { MockContractFactory, MockContract, FakeContract, smock } from "@defi-wonderland/smock";

const { expect } = chai;
chai.use(smock.matchers);

describe("Stability Pool Operations", () => {
    let testLibrariesFactory: MockContractFactory<TestLibraries__factory>;
    let testLibraries: MockContract<TestLibraries>;
    let stabilityPool: FakeContract<StabilityPool>;
    let signers: SignerWithAddress[];
    beforeEach(async () => {
        signers = await ethers.getSigners();

        stabilityPool = await smock.fake<StabilityPool>("StabilityPool");

        testLibrariesFactory = await smock.mock<TestLibraries__factory>("TestLibraries");

        testLibraries = await testLibrariesFactory.deploy(stabilityPool.target);
        await testLibraries.waitForDeployment();
    });
    describe("Provide funds to Stability Pool", async () => {
        it("should call provideToSP with correct parameters", async () => {});
        await testLibraries.testProvideToSP(100);
        expect(stabilityPool.provideToSP).to.be.calledWith(100, 0x0);
    });
    describe("Withdraw funds from Stability Pool", async () => {
        it("should call provideToSP with correct parameters", async () => {});
        await testLibraries.testWithdrawFromSP(100);
        expect(stabilityPool.withdrawFromSP).to.be.calledWith(100, 0x0);
    });
    describe("Withdraw RBTC gain to trove", async () => {
        it("should call withdrawETHGainToTrove with borrower address as parameters", async () => {});
        await testLibraries.testWithdrawRBTCGainToTrove();
        expect(stabilityPool.withdrawETHGainToTrove).to.be.calledWith(
            signers[0].address,
            signers[0].address
        );
    });
});
*/
