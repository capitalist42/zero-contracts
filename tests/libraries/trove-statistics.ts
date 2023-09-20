/* eslint-disable no-unused-expressions */
/* eslint-disable camelcase */
/* eslint-disable node/no-missing-import */

/* @todo remove when the libraries tests transitioned to Foundry 

import { TestLibraries } from "../../types/generated";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { TestLibraries__factory } from "../../types/generated";
import { TroveManager } from "../../types/generated";
import { ethers } from "hardhat";
import chai from "chai";
import { MockContractFactory, MockContract, FakeContract, smock } from "@defi-wonderland/smock";

const { expect } = chai;
chai.use(smock.matchers);

describe("Trove Statistics View Operations", () => {
    let testLibrariesFactory: MockContractFactory<TestLibraries__factory>;
    let testLibraries: MockContract<TestLibraries>;
    let troveManager: FakeContract<TroveManager>;
    let signers: SignerWithAddress[];
    beforeEach(async () => {
        signers = await ethers.getSigners();

        troveManager = await smock.fake<TroveManager>("TroveManager");

        testLibrariesFactory = await smock.mock<TestLibraries__factory>("TestLibraries");

        testLibraries = await testLibrariesFactory.deploy(troveManager.target);
        await testLibraries.waitForDeployment();
    });
    describe("Get ICR of borrower", async () => {
        it("should call getNominalICR in Trove Manager", async () => {
            await testLibraries.testGetNominalICR(signers[1].address);
            expect(troveManager.getNominalICR).to.have.been.calledOnceWith(signers[1].address);
        });
    });

    describe("Get entire Debt and Collateral of borrower", async () => {
        it("should call liquidate trove function with correct number of max troves to liquadte", async () => {
            await testLibraries.testGetEntireDebtAndColl(signers[1].address);
            expect(troveManager.getEntireDebtAndColl).to.have.been.calledOnceWith(
                signers[1].address
            );
        });
    });
    describe("Calculate Borrowing Fee", async () => {
        it("should call calculateBorrowingFee with the correct params", async () => {});
        await testLibraries.testCalculateBorrowingFee(100);
        expect(troveManager.getBorrowingFee).to.have.been.calledOnceWith(100);
    });
});

*/
