/* eslint-disable no-unused-expressions */
/* eslint-disable camelcase */
/* eslint-disable node/no-missing-import */

/* @todo remove when the libraries tests transitioned to Foundry 

import { ethers } from "hardhat";
import { TestLibraries } from "../../types/generated";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { TestLibraries__factory } from "../../types/generated";
import { BorrowerOperations } from "../../types/generated";
import chai from "chai";
import { MockContractFactory, MockContract, FakeContract, smock } from "@defi-wonderland/smock";

const { expect } = chai;
chai.use(smock.matchers);

describe("Borrower Library Operations", () => {
    let testLibrariesFactory: MockContractFactory<TestLibraries__factory>;
    let testLibraries: MockContract<TestLibraries>;
    let borrower: FakeContract<BorrowerOperations>;
    let signers: SignerWithAddress[];
    beforeEach(async () => {
        signers = await ethers.getSigners();

        borrower = await smock.fake<BorrowerOperations>("BorrowerOperations");

        testLibrariesFactory = await smock.mock<TestLibraries__factory>("TestLibraries");

        testLibraries = await testLibrariesFactory.deploy(borrower.target);
        await testLibraries.waitForDeployment();
    });

    describe("Borrowing ZUSD", async () => {
        it("should call withdraw function with correct parameters", async () => {
            await testLibraries.testOpenCreditLine(1, 100, {
                value: ethers.parseEther("1.0"),
            });
            expect(borrower.openTrove).to.have.been.calledOnceWith(
                1,
                100,
                signers[0].address,
                signers[0].address
            );
        });
    });

    describe("Withdrawing ZUSD", async () => {
        it("should call withdraw function with correct parameters", async () => {
            await testLibraries.testWithdrawZUSD(1, 100);
            expect(borrower.withdrawZUSD).to.have.been.calledOnceWith(
                1,
                100,
                signers[0].address,
                signers[0].address
            );
        });
    });
    describe("Withdrawing collateral", async () => {
        it("should call withdraw collateral function with correct parameters", async () => {
            await testLibraries.testWithdrawCollateral(1);
            expect(borrower.withdrawColl).to.have.been.calledOnceWith(
                1,
                signers[0].address,
                signers[0].address
            );
        });
    });
    describe("Repaying ZUSD", async () => {
        it("should call repay function with correct parameters", async () => {
            await testLibraries.testRepayZUSD(100);
            expect(borrower.repayZUSD).to.have.been.calledOnceWith(
                100,
                signers[0].address,
                signers[0].address
            );
        });
    });
    describe("Adding collateral", async () => {
        it("should call add collateral function with correct parameters", async () => {
            await testLibraries.testAddCollateral({
                value: ethers.parseEther("1.0"),
            });
            expect(borrower.addColl).to.have.been.calledOnceWith(
                signers[0].address,
                signers[0].address
            );
        });
    });
    describe("Close Credit Line and Withdraw Collateral", async () => {
        it("should call close trove function", async () => {
            await testLibraries.testCloseCreditLineAndWithdrawCollateral();
            expect(borrower.closeTrove).to.be.calledOnce;
        });
    });
});
*/
