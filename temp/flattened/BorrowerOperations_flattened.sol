// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

interface IMassetManager {
    struct PermitParams {
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function mintTo(
        address _bAsset,
        uint256 _bAssetQuantity,
        address _recipient
    ) external returns (uint256);

    function getToken() external view returns (address);

    /**
     * @dev Credits a recipient with a certain quantity of selected bAsset, in exchange for burning the
     *      relative mAsset quantity from the sender. Sender also incurs a small fee, if any.
     * @param _bAsset           Address of the bAsset to redeem.
     * @param _massetQuantity   Units of the masset to redeem.
     * @param _recipient        Address to credit with withdrawn bAssets.
     * @return massetRedeemed   Relative number of mAsset units burned to pay for the bAssets.
     */
    function redeemTo(
        address _bAsset,
        uint256 _massetQuantity,
        address _recipient
    ) external returns (uint256 massetRedeemed);
}


// File contracts/Dependencies/Ownable.sol



pragma solidity 0.6.11;

/**
 * Based on OpenZeppelin's Ownable contract:
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol
 *
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable {
    bytes32 private constant KEY_OWNER = keccak256("key.ownable.owner");

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        _setOwner(msg.sender);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == getOwner(), "Ownable:: access denied");
        _;
    }

    /**
     * @notice Set address of the owner.
     * @param _owner Address of the owner.
     * */
    function _setOwner(address _owner) internal {
        require(_owner != address(0), "Ownable::setOwner: invalid address");
        emit OwnershipTransferred(getOwner(), _owner);

        bytes32 key = KEY_OWNER;
        assembly {
            sstore(key, _owner)
        }
    }

    /**
     * @notice Set address of the owner (only owner can call this function)
     * @param _owner Address of the owner.
     * */
    function setOwner(address _owner) public onlyOwner {
        _setOwner(_owner);
    }

    /**
     * @notice Return address of the owner.
     * @return _owner Address of the owner.
     * */
    function getOwner() public view returns (address _owner) {
        bytes32 key = KEY_OWNER;
        assembly {
            _owner := sload(key)
        }
    }
}


// File contracts/Interfaces/IPool.sol



pragma solidity 0.6.11;

// Common interface for the Pools.
interface IPool {
    // --- Events ---

    event ETHBalanceUpdated(uint _newBalance);
    event ZUSDBalanceUpdated(uint _newBalance);
    event ActivePoolAddressChanged(address _newActivePoolAddress);
    event DefaultPoolAddressChanged(address _newDefaultPoolAddress);
    event StabilityPoolAddressChanged(address _newStabilityPoolAddress);
    event EtherSent(address _to, uint _amount);

    // --- Functions ---

    /// @notice Not necessarily equal to the raw ether balance - ether can be forcibly sent to contracts.
    /// @return ETH pool balance
    function getETH() external view returns (uint);

    /// @return ZUSD debt pool balance
    function getZUSDDebt() external view returns (uint);

    /// @notice Increases ZUSD debt of the pool.
    /// @param _amount ZUSD amount to add to the pool debt
    function increaseZUSDDebt(uint _amount) external;

    /// @notice Decreases ZUSD debt of the pool.
    /// @param _amount ZUSD amount to subtract to the pool debt
    function decreaseZUSDDebt(uint _amount) external;
}


// File contracts/Interfaces/IActivePool.sol



pragma solidity 0.6.11;

/**
 * The Active Pool holds the ETH collateral and ZUSD debt (but not ZUSD tokens) for all active troves.
 *
 * When a trove is liquidated, it's ETH and ZUSD debt are transferred from the Active Pool, to either the
 * Stability Pool, the Default Pool, or both, depending on the liquidation conditions.
 *
 */
interface IActivePool is IPool {
    // --- Events ---
    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event ActivePoolZUSDDebtUpdated(uint _ZUSDDebt);
    event ActivePoolETHBalanceUpdated(uint _ETH);

    // --- Functions ---

    /// @notice Send ETH amount to given account. Updates ActivePool balance. Only callable by BorrowerOperations, TroveManager or StabilityPool.
    /// @param _account account to receive the ETH amount
    /// @param _amount ETH amount to send
    function sendETH(address _account, uint _amount) external;
}


// File contracts/Interfaces/IBorrowerOperations.sol



pragma solidity 0.6.11;


/// Common interface for the Trove Manager.
interface IBorrowerOperations {
    // --- Events ---

    event FeeDistributorAddressChanged(address _feeDistributorAddress);
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event ActivePoolAddressChanged(address _activePoolAddress);
    event DefaultPoolAddressChanged(address _defaultPoolAddress);
    event StabilityPoolAddressChanged(address _stabilityPoolAddress);
    event GasPoolAddressChanged(address _gasPoolAddress);
    event CollSurplusPoolAddressChanged(address _collSurplusPoolAddress);
    event PriceFeedAddressChanged(address _newPriceFeedAddress);
    event SortedTrovesAddressChanged(address _sortedTrovesAddress);
    event ZUSDTokenAddressChanged(address _zusdTokenAddress);
    event ZEROStakingAddressChanged(address _zeroStakingAddress);

    event TroveCreated(address indexed _borrower, uint256 arrayIndex);
    event TroveUpdated(
        address indexed _borrower,
        uint256 _debt,
        uint256 _coll,
        uint256 stake,
        uint8 operation
    );
    event ZUSDBorrowingFeePaid(address indexed _borrower, uint256 _ZUSDFee);

    // --- Functions ---

    /**
     * @notice Called only once on init, to set addresses of other Zero contracts. Callable only by owner
     * @dev initializer function, checks addresses are contracts
     * @param _feeDistributorAddress feeDistributor contract address
     * @param _liquityBaseParamsAddress LiquidityBaseParams contract address
     * @param _troveManagerAddress TroveManager contract address
     * @param _activePoolAddress ActivePool contract address
     * @param _defaultPoolAddress DefaultPool contract address
     * @param _stabilityPoolAddress StabilityPool contract address
     * @param _gasPoolAddress GasPool contract address
     * @param _collSurplusPoolAddress CollSurplusPool contract address
     * @param _priceFeedAddress PrideFeed contract address
     * @param _sortedTrovesAddress SortedTroves contract address
     * @param _zusdTokenAddress ZUSDToken contract address
     * @param _zeroStakingAddress ZEROStaking contract address
     */
    function setAddresses(
        address _feeDistributorAddress,
        address _liquityBaseParamsAddress,
        address _troveManagerAddress,
        address _activePoolAddress,
        address _defaultPoolAddress,
        address _stabilityPoolAddress,
        address _gasPoolAddress,
        address _collSurplusPoolAddress,
        address _priceFeedAddress,
        address _sortedTrovesAddress,
        address _zusdTokenAddress,
        address _zeroStakingAddress
    ) external;

    /**
     * @notice payable function that creates a Trove for the caller with the requested debt, and the Ether received as collateral.
     * Successful execution is conditional mainly on the resulting collateralization ratio which must exceed the minimum (110% in Normal Mode, 150% in Recovery Mode).
     * In addition to the requested debt, extra debt is issued to pay the issuance fee, and cover the gas compensation.
     * The borrower has to provide a `_maxFeePercentage` that he/she is willing to accept in case of a fee slippage, i.e. when a redemption transaction is processed first, driving up the issuance fee.
     * @param _maxFee max fee percentage to acept in case of a fee slippage
     * @param _ZUSDAmount ZUSD requested debt
     * @param _upperHint upper trove id hint
     * @param _lowerHint lower trove id hint
     */
    function openTrove(
        uint256 _maxFee,
        uint256 _ZUSDAmount,
        address _upperHint,
        address _lowerHint
    ) external payable;

    /**
     * @notice payable function that creates a Trove for the caller with the requested debt, and the Ether received as collateral.
     * Successful execution is conditional mainly on the resulting collateralization ratio which must exceed the minimum (110% in Normal Mode, 150% in Recovery Mode).
     * In addition to the requested debt, extra debt is issued to pay the issuance fee, and cover the gas compensation.
     * The borrower has to provide a `_maxFeePercentage` that he/she is willing to accept in case of a fee slippage, i.e. when a redemption transaction is processed first, driving up the issuance fee.
     * This method is identical to `openTrove()`, but operates on NUE tokens instead of ZUSD.
     * @param _maxFee max fee percentage to acept in case of a fee slippage
     * @param _ZUSDAmount ZUSD requested debt
     * @param _upperHint upper trove id hint
     * @param _lowerHint lower trove id hint
     */
    function openNueTrove(
        uint256 _maxFee,
        uint256 _ZUSDAmount,
        address _upperHint,
        address _lowerHint
    ) external payable;

    /// @notice payable function that adds the received Ether to the caller's active Trove.
    /// @param _upperHint upper trove id hint
    /// @param _lowerHint lower trove id hint
    function addColl(address _upperHint, address _lowerHint) external payable;

    /// @notice send ETH as collateral to a trove. Called by only the Stability Pool.
    /// @param _user user trove address
    /// @param _upperHint upper trove id hint
    /// @param _lowerHint lower trove id hint
    function moveETHGainToTrove(
        address _user,
        address _upperHint,
        address _lowerHint
    ) external payable;

    /**
     * @notice withdraws `_amount` of collateral from the caller’s Trove.
     * Executes only if the user has an active Trove, the withdrawal would not pull the user’s Trove below the minimum collateralization ratio,
     * and the resulting total collateralization ratio of the system is above 150%.
     * @param _amount collateral amount to withdraw
     * @param _upperHint upper trove id hint
     * @param _lowerHint lower trove id hint
     */
    function withdrawColl(uint256 _amount, address _upperHint, address _lowerHint) external;

    /**
     * @notice issues `_amount` of ZUSD from the caller’s Trove to the caller.
     * Executes only if the Trove's collateralization ratio would remain above the minimum, and the resulting total collateralization ratio is above 150%.
     * The borrower has to provide a `_maxFeePercentage` that he/she is willing to accept in case of a fee slippage, i.e. when a redemption transaction is processed first, driving up the issuance fee.
     * @param _maxFee max fee percentage to acept in case of a fee slippage
     * @param _amount ZUSD amount to withdraw
     * @param _upperHint upper trove id hint
     * @param _lowerHint lower trove id hint
     */
    function withdrawZUSD(
        uint256 _maxFee,
        uint256 _amount,
        address _upperHint,
        address _lowerHint
    ) external;

    /// Borrow (withdraw) ZUSD tokens from a trove: mint new ZUSD tokens to the owner and convert it to DLLR in one transaction
    function withdrawZusdAndConvertToDLLR(
        uint256 _maxFeePercentage,
        uint256 _ZUSDAmount,
        address _upperHint,
        address _lowerHint
    ) external returns (uint256);

    /// @notice repay `_amount` of ZUSD to the caller’s Trove, subject to leaving 50 debt in the Trove (which corresponds to the 50 ZUSD gas compensation).
    /// @param _amount ZUSD amount to repay
    /// @param _upperHint upper trove id hint
    /// @param _lowerHint lower trove id hint
    function repayZUSD(uint256 _amount, address _upperHint, address _lowerHint) external;

    /// Repay ZUSD tokens to a Trove: Burn the repaid ZUSD tokens, and reduce the trove's debt accordingly
    function repayZusdFromDLLR(
        uint256 _dllrAmount,
        address _upperHint,
        address _lowerHint,
        IMassetManager.PermitParams calldata _permitParams
    ) external;

    /**
     * @notice allows a borrower to repay all debt, withdraw all their collateral, and close their Trove.
     * Requires the borrower have a ZUSD balance sufficient to repay their trove's debt, excluding gas compensation - i.e. `(debt - 50)` ZUSD.
     */
    function closeTrove() external;

    /**
     * @notice allows a borrower to repay all debt, withdraw all their collateral, and close their Trove.
     * Requires the borrower have a NUE balance sufficient to repay their trove's debt, excluding gas compensation - i.e. `(debt - 50)` NUE.
     * This method is identical to `closeTrove()`, but operates on NUE tokens instead of ZUSD.
     */
    function closeNueTrove(IMassetManager.PermitParams calldata _permitParams) external;

    /**
     * @notice enables a borrower to simultaneously change both their collateral and debt, subject to all the restrictions that apply to individual increases/decreases of each quantity with the following particularity:
     * if the adjustment reduces the collateralization ratio of the Trove, the function only executes if the resulting total collateralization ratio is above 150%.
     * The borrower has to provide a `_maxFeePercentage` that he/she is willing to accept in case of a fee slippage, i.e. when a redemption transaction is processed first, driving up the issuance fee.
     * The parameter is ignored if the debt is not increased with the transaction.
     * @param _maxFee max fee percentage to acept in case of a fee slippage
     * @param _collWithdrawal collateral amount to withdraw
     * @param _debtChange ZUSD amount to change
     * @param isDebtIncrease indicates if increases debt
     * @param _upperHint upper trove id hint
     * @param _lowerHint lower trove id hint
     */
    function adjustTrove(
        uint256 _maxFee,
        uint256 _collWithdrawal,
        uint256 _debtChange,
        bool isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external payable;

    /**
     * @notice enables a borrower to simultaneously change both their collateral and debt, subject to all the restrictions that apply to individual increases/decreases of each quantity with the following particularity:
     * if the adjustment reduces the collateralization ratio of the Trove, the function only executes if the resulting total collateralization ratio is above 150%.
     * The borrower has to provide a `_maxFeePercentage` that he/she is willing to accept in case of a fee slippage, i.e. when a redemption transaction is processed first, driving up the issuance fee.
     * The parameter is ignored if the debt is not increased with the transaction.
     * This method is identical to `adjustTrove()`, but operates on NUE tokens instead of ZUSD.
     * @param _maxFee max fee percentage to acept in case of a fee slippage
     * @param _collWithdrawal collateral amount to withdraw
     * @param _debtChange ZUSD amount to change
     * @param isDebtIncrease indicates if increases debt
     * @param _upperHint upper trove id hint
     * @param _lowerHint lower trove id hint
     */
    function adjustNueTrove(
        uint256 _maxFee,
        uint256 _collWithdrawal,
        uint256 _debtChange,
        bool isDebtIncrease,
        address _upperHint,
        address _lowerHint,
        IMassetManager.PermitParams calldata _permitParams
    ) external payable;

    /**
     * @notice when a borrower’s Trove has been fully redeemed from and closed, or liquidated in Recovery Mode with a collateralization ratio above 110%,
     * this function allows the borrower to claim their ETH collateral surplus that remains in the system (collateral - debt upon redemption; collateral - 110% of the debt upon liquidation).
     */
    function claimCollateral() external;

    function getCompositeDebt(uint256 _debt) external view returns (uint256);

    function BORROWING_FEE_FLOOR() external view returns (uint256);

    function getMassetManager() external view returns (IMassetManager);
}


// File contracts/Interfaces/ICollSurplusPool.sol



pragma solidity 0.6.11;

interface ICollSurplusPool {
    // --- Events ---

    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event ActivePoolAddressChanged(address _newActivePoolAddress);

    event CollBalanceUpdated(address indexed _account, uint256 _newBalance);
    event EtherSent(address _to, uint256 _amount);

    // --- Contract setters ---

    /**
     * @notice Called only once on init, to set addresses of other Zero contracts. Callable only by owner
     * @dev initializer function, checks addresses are contracts
     * @param _borrowerOperationsAddress BorrowerOperations contract address
     * @param _troveManagerAddress TroveManager contract address
     * @param _activePoolAddress ActivePool contract address
     */
    function setAddresses(
        address _borrowerOperationsAddress,
        address _troveManagerAddress,
        address _activePoolAddress
    ) external;

    /// @notice Not necessarily equal to the raw ether balance - ether can be forcibly sent to contracts.
    /// @return ETH state variable
    function getETH() external view returns (uint256);

    /// @param _account account to retrieve collateral
    /// @return collateral
    function getCollateral(address _account) external view returns (uint256);

    /// @notice adds amount to current account balance. Only callable by TroveManager.
    /// @param _account account to add amount
    /// @param _amount amount to add
    function accountSurplus(address _account, uint256 _amount) external;

    /// @notice claims collateral for given account. Only callable by BorrowerOperations.
    /// @param _account account to send claimable collateral
    function claimColl(address _account) external;
}


// File contracts/Interfaces/IFeeDistributor.sol



pragma solidity 0.6.11;

/// Common interface for Fee Distributor.
interface IFeeDistributor {
    // --- Events ---

    event FeeSharingCollectorAddressChanged(address _feeSharingCollectorAddress);
    event ZeroStakingAddressChanged(address _zeroStakingAddress);
    event BorrowerOperationsAddressChanged(address _borrowerOperationsAddress);
    event TroveManagerAddressChanged(address _troveManagerAddress);
    event WrbtcAddressChanged(address _wrbtcAddress);
    event ZUSDTokenAddressChanged(address _zusdTokenAddress);
    event ActivePoolAddressSet(address _activePoolAddress);

    event ZUSDDistributed(uint256 _zusdDistributedAmount);
    event RBTCistributed(uint256 _rbtcDistributedAmount);

    // --- Functions ---

    /**
     * @notice Called only once on init, to set addresses of other Zero contracts. Callable only by owner
     * @dev initializer function, checks addresses are contracts
     * @param _feeSharingCollectorAddress FeeSharingCollector address
     * @param _zeroStakingAddress ZEROStaking contract address
     * @param _borrowerOperationsAddress borrowerOperations contract address
     * @param _troveManagerAddress TroveManager contract address
     * @param _wrbtcAddress wrbtc ERC20 contract address
     * @param _zusdTokenAddress ZUSDToken contract address
     * @param _activePoolAddress ActivePool contract address
     */
    function setAddresses(
        address _feeSharingCollectorAddress,
        address _zeroStakingAddress,
        address _borrowerOperationsAddress,
        address _troveManagerAddress,
        address _wrbtcAddress,
        address _zusdTokenAddress,
        address _activePoolAddress
    ) external;

    function distributeFees() external;
}


// File contracts/Interfaces/ISortedTroves.sol



pragma solidity 0.6.11;

// Common interface for the SortedTroves Doubly Linked List.
interface ISortedTroves {
    // --- Events ---

    event SortedTrovesAddressChanged(address _sortedDoublyLLAddress);
    event BorrowerOperationsAddressChanged(address _borrowerOperationsAddress);
    event NodeAdded(address _id, uint256 _NICR);
    event NodeRemoved(address _id);

    // --- Functions ---

    /**
     * @notice Called only once on init, to set addresses of other Zero contracts and size. Callable only by owner
     * @dev initializer function, checks addresses are contracts
     * @param _size max size of troves list
     * @param _TroveManagerAddress TroveManager contract address
     * @param _borrowerOperationsAddress BorrowerOperations contract address
     */
    function setParams(
        uint256 _size,
        address _TroveManagerAddress,
        address _borrowerOperationsAddress
    ) external;

    /**
     * @dev Add a node to the list
     * @param _id Node's id
     * @param _ICR Node's NICR
     * @param _prevId Id of previous node for the insert position
     * @param _nextId Id of next node for the insert position
     */
    function insert(
        address _id,
        uint256 _ICR,
        address _prevId,
        address _nextId
    ) external;

    /**
     * @dev Remove a node from the list
     * @param _id Node's id
     */
    function remove(address _id) external;

    /**
     * @dev Re-insert the node at a new position, based on its new NICR
     * @param _id Node's id
     * @param _newICR Node's new NICR
     * @param _prevId Id of previous node for the new insert position
     * @param _nextId Id of next node for the new insert position
     */
    function reInsert(
        address _id,
        uint256 _newICR,
        address _prevId,
        address _nextId
    ) external;

    /**
     * @dev Checks if the list contains a node
     * @param _id Node's id
     * @return true if list contains a node with given id
     */
    function contains(address _id) external view returns (bool);

    /**
     * @dev Checks if the list is full
     * @return true if list is full
     */
    function isFull() external view returns (bool);

    /**
     * @dev Checks if the list is empty
     * @return true if list is empty
     */
    function isEmpty() external view returns (bool);

    /**
     * @return list current size
     */
    function getSize() external view returns (uint256);

    /**
     * @return list max size
     */
    function getMaxSize() external view returns (uint256);

    /**
     * @return the first node in the list (node with the largest NICR)
     */
    function getFirst() external view returns (address);

    /**
     * @return the last node in the list (node with the smallest NICR)
     */
    function getLast() external view returns (address);

    /**
     * @param _id Node's id
     * @return the next node (with a smaller NICR) in the list for a given node
     */
    function getNext(address _id) external view returns (address);

    /**
     * @param _id Node's id
     * @return the previous node (with a larger NICR) in the list for a given node
     */
    function getPrev(address _id) external view returns (address);

    /**
     * @notice Check if a pair of nodes is a valid insertion point for a new node with the given NICR
     * @param _ICR Node's NICR
     * @param _prevId Id of previous node for the insert position
     * @param _nextId Id of next node for the insert position
     */
    function validInsertPosition(
        uint256 _ICR,
        address _prevId,
        address _nextId
    ) external view returns (bool);

    /**
     * @notice Find the insert position for a new node with the given NICR
     * @param _ICR Node's NICR
     * @param _prevId Id of previous node for the insert position
     * @param _nextId Id of next node for the insert position
     */
    function findInsertPosition(
        uint256 _ICR,
        address _prevId,
        address _nextId
    ) external view returns (address, address);
}


// File contracts/Interfaces/ILiquityBaseParams.sol



pragma solidity 0.6.11;

interface ILiquityBaseParams {

    /// Minimum collateral ratio for individual troves
    function MCR() external view returns (uint);

    /// Critical system collateral ratio. If the system's total collateral ratio (TCR) falls below the CCR, Recovery Mode is triggered.
    function CCR() external view returns (uint);

    function PERCENT_DIVISOR() external view returns (uint);

    function BORROWING_FEE_FLOOR() external view returns (uint);

    /**
     * Half-life of 12h. 12h = 720 min
     * (1/2) = d^720 => d = (1/2)^(1/720)
     */
    function REDEMPTION_FEE_FLOOR() external view returns (uint);

    function MAX_BORROWING_FEE() external view returns (uint);

}


// File contracts/Interfaces/IPriceFeed.sol



pragma solidity 0.6.11;

interface IPriceFeed {
    // --- Events ---
    event LastGoodPriceUpdated(uint256 _lastGoodPrice);

    // --- Function ---

    /// @notice Returns the latest price obtained from the Oracle. Called by Zero functions that require a current price.
    ///         It uses the main price feed and fallback to the backup one in case of an error. If both fail return the last
    ///         good price seen.
    /// @dev It's also callable by anyone externally
    /// @return The price
    function fetchPrice() external returns (uint256);
}


// File contracts/Interfaces/ILiquityBase.sol



pragma solidity 0.6.11;


interface ILiquityBase {
    /// @return PriceFeed contract
    function priceFeed() external view returns (IPriceFeed);

    /// @return LiquityBaseParams contract
    function liquityBaseParams() external view returns (ILiquityBaseParams);
}


// File contracts/Interfaces/IStabilityPool.sol



pragma solidity 0.6.11;


/*
 * The Stability Pool holds ZUSD tokens deposited by Stability Pool depositors.
 *
 * When a trove is liquidated, then depending on system conditions, some of its ZUSD debt gets offset with
 * ZUSD in the Stability Pool:  that is, the offset debt evaporates, and an equal amount of ZUSD tokens in the Stability Pool is burned.
 *
 * Thus, a liquidation causes each depositor to receive a ZUSD loss, in proportion to their deposit as a share of total deposits.
 * They also receive an ETH gain, as the ETH collateral of the liquidated trove is distributed among Stability depositors,
 * in the same proportion.
 *
 * When a liquidation occurs, it depletes every deposit by the same fraction: for example, a liquidation that depletes 40%
 * of the total ZUSD in the Stability Pool, depletes 40% of each deposit.
 *
 * A deposit that has experienced a series of liquidations is termed a "compounded deposit": each liquidation depletes the deposit,
 * multiplying it by some factor in range ]0,1[
 *
 * Please see the implementation spec in the proof document, which closely follows on from the compounded deposit / ETH gain derivations:
 * https://github.com/liquity/liquity/blob/master/papers/Scalable_Reward_Distribution_with_Compounding_Stakes.pdf
 *
 * --- ZERO ISSUANCE TO STABILITY POOL DEPOSITORS ---
 *
 * An ZERO issuance event occurs at every deposit operation, and every liquidation.
 *
 * Each deposit is tagged with the address of the front end through which it was made.
 *
 * All deposits earn a share of the issued ZERO in proportion to the deposit as a share of total deposits. The ZERO earned
 * by a given deposit, is split between the depositor and the front end through which the deposit was made, based on the front end's kickbackRate.
 *
 * Please see the system Readme for an overview:
 * https://github.com/liquity/dev/blob/main/README.md#zero-issuance-to-stability-providers
 */
interface IStabilityPool {
    // --- Events ---

    event StabilityPoolETHBalanceUpdated(uint _newBalance);
    event StabilityPoolZUSDBalanceUpdated(uint _newBalance);

    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event ActivePoolAddressChanged(address _newActivePoolAddress);
    event DefaultPoolAddressChanged(address _newDefaultPoolAddress);
    event ZUSDTokenAddressChanged(address _newZUSDTokenAddress);
    event SortedTrovesAddressChanged(address _newSortedTrovesAddress);
    event PriceFeedAddressChanged(address _newPriceFeedAddress);
    event CommunityIssuanceAddressChanged(address _newCommunityIssuanceAddress);

    event P_Updated(uint _P);
    event S_Updated(uint _S, uint128 _epoch, uint128 _scale);
    event G_Updated(uint _G, uint128 _epoch, uint128 _scale);
    event EpochUpdated(uint128 _currentEpoch);
    event ScaleUpdated(uint128 _currentScale);

    event FrontEndRegistered(address indexed _frontEnd, uint _kickbackRate);
    event FrontEndTagSet(address indexed _depositor, address indexed _frontEnd);

    event DepositSnapshotUpdated(address indexed _depositor, uint _P, uint _S, uint _G);
    event FrontEndSnapshotUpdated(address indexed _frontEnd, uint _P, uint _G);
    event UserDepositChanged(address indexed _depositor, uint _newDeposit);
    event FrontEndStakeChanged(
        address indexed _frontEnd,
        uint _newFrontEndStake,
        address _depositor
    );

    event ETHGainWithdrawn(address indexed _depositor, uint _ETH, uint _ZUSDLoss);
    event ZEROPaidToDepositor(address indexed _depositor, uint _ZERO);
    event ZEROPaidToFrontEnd(address indexed _frontEnd, uint _ZERO);
    event EtherSent(address _to, uint _amount);

    event WithdrawFromSpAndConvertToDLLR(
        address _depositor,
        uint256 _zusdAmountRequested,
        uint256 _dllrAmountReceived
    );

    // --- Functions ---

    /**
     * @notice Called only once on init, to set addresses of other Liquity contracts. Callable only by owner
     * @dev initializer function, checks addresses are contracts
     * @param _liquityBaseParamsAddress LiquidityBaseParams contract address
     * @param _borrowerOperationsAddress BorrowerOperations contract address
     * @param _troveManagerAddress TroveManager contract address
     * @param _activePoolAddress ActivePool contract address
     * @param _zusdTokenAddress ZUSDToken contract address
     * @param _sortedTrovesAddress SortedTroves contract address
     * @param _priceFeedAddress PriceFeed contract address
     * @param _communityIssuanceAddress CommunityIssuanceAddress
     */
    function setAddresses(
        address _liquityBaseParamsAddress,
        address _borrowerOperationsAddress,
        address _troveManagerAddress,
        address _activePoolAddress,
        address _zusdTokenAddress,
        address _sortedTrovesAddress,
        address _priceFeedAddress,
        address _communityIssuanceAddress
    ) external;

    /**
     * @notice Initial checks:
     *  - Frontend is registered or zero address
     *  - Sender is not a registered frontend
     *  - _amount is not zero
     *  ---
     *  - Triggers a ZERO issuance, based on time passed since the last issuance. The ZERO issuance is shared between *all* depositors and front ends
     *  - Tags the deposit with the provided front end tag param, if it's a new deposit
     *  - Sends depositor's accumulated gains (ZERO, ETH) to depositor
     *  - Sends the tagged front end's accumulated ZERO gains to the tagged front end
     *  - Increases deposit and tagged front end's stake, and takes new snapshots for each.
     * @param _amount amount to provide
     * @param _frontEndTag frontend address to receive accumulated ZERO gains
     */
    function provideToSP(uint _amount, address _frontEndTag) external;

    /**
     * @notice Initial checks:
     *    - _amount is zero or there are no under collateralized troves left in the system
     *    - User has a non zero deposit
     *    ---
     *    - Triggers a ZERO issuance, based on time passed since the last issuance. The ZERO issuance is shared between *all* depositors and front ends
     *    - Removes the deposit's front end tag if it is a full withdrawal
     *    - Sends all depositor's accumulated gains (ZERO, ETH) to depositor
     *    - Sends the tagged front end's accumulated ZERO gains to the tagged front end
     *    - Decreases deposit and tagged front end's stake, and takes new snapshots for each.
     *
     *    If _amount > userDeposit, the user withdraws all of their compounded deposit.
     * @param _amount amount to withdraw
     */
    function withdrawFromSP(uint _amount) external;

    /**
     * @notice Initial checks:
     *    - User has a non zero deposit
     *    - User has an open trove
     *    - User has some ETH gain
     *    ---
     *    - Triggers a ZERO issuance, based on time passed since the last issuance. The ZERO issuance is shared between *all* depositors and front ends
     *    - Sends all depositor's ZERO gain to  depositor
     *    - Sends all tagged front end's ZERO gain to the tagged front end
     *    - Transfers the depositor's entire ETH gain from the Stability Pool to the caller's trove
     *    - Leaves their compounded deposit in the Stability Pool
     *    - Updates snapshots for deposit and tagged front end stake
     * @param _upperHint upper trove id hint
     * @param _lowerHint lower trove id hint
     */
    function withdrawETHGainToTrove(address _upperHint, address _lowerHint) external;

    /**
     * @notice Initial checks:
     *    - Frontend (sender) not already registered
     *    - User (sender) has no deposit
     *    - _kickbackRate is in the range [0, 100%]
     *    ---
     *    Front end makes a one-time selection of kickback rate upon registering
     * @param _kickbackRate kickback rate selected by frontend
     */
    function registerFrontEnd(uint _kickbackRate) external;

    /**
     * @notice Initial checks:
     *    - Caller is TroveManager
     *    ---
     *    Cancels out the specified debt against the ZUSD contained in the Stability Pool (as far as possible)
     *    and transfers the Trove's ETH collateral from ActivePool to StabilityPool.
     *    Only called by liquidation functions in the TroveManager.
     * @param _debt debt to cancel
     * @param _coll collateral to transfer
     */
    function offset(uint _debt, uint _coll) external;

    /**
     * @return the total amount of ETH held by the pool, accounted in an internal variable instead of `balance`,
     * to exclude edge cases like ETH received from a self-destruct.
     */
    function getETH() external view returns (uint);

    /**
     * @return ZUSD held in the pool. Changes when users deposit/withdraw, and when Trove debt is offset.
     */
    function getTotalZUSDDeposits() external view returns (uint);

    /**
     * @notice Calculates the ETH gain earned by the deposit since its last snapshots were taken.
     * @param _depositor address to calculate ETH gain
     * @return ETH gain from given depositor
     */
    function getDepositorETHGain(address _depositor) external view returns (uint);

    /**
     * @notice Calculate the ZERO gain earned by a deposit since its last snapshots were taken.
     *    If not tagged with a front end, the depositor gets a 100% cut of what their deposit earned.
     *    Otherwise, their cut of the deposit's earnings is equal to the kickbackRate, set by the front end through
     *    which they made their deposit.
     * @param _depositor address to calculate ETH gain
     * @return ZERO gain from given depositor
     */
    function getDepositorZEROGain(address _depositor) external view returns (uint);

    /**
     * @param _frontEnd front end address
     * @return the ZERO gain earned by the front end.
     */
    function getFrontEndZEROGain(address _frontEnd) external view returns (uint);

    /**
     * @param _depositor depositor address
     * @return the user's compounded deposit.
     */
    function getCompoundedZUSDDeposit(address _depositor) external view returns (uint);

    /**
     * @notice The front end's compounded stake is equal to the sum of its depositors' compounded deposits.
     * @param _frontEnd front end address
     * @return the front end's compounded stake.
     */
    function getCompoundedFrontEndStake(address _frontEnd) external view returns (uint);

    //DLLR _owner or _spender can convert a specified amount of DLLR into ZUSD via Sovryn Mynt and deposit the ZUSD into the Zero Stability Pool, all in a single transaction
    function provideToSpFromDLLR(
        uint _dllrAmount,
        IMassetManager.PermitParams calldata _permitParams
    ) external;

    /// Stability Pool depositor can withdraw a specified amount of ZUSD from the Zero Stability Pool and optionally convert the ZUSD to DLLR via Sovryn Mynt, all in a single transaction
    function withdrawFromSpAndConvertToDLLR(uint256 _zusdAmount) external;

    /**
     * Fallback function
     * Only callable by Active Pool, it just accounts for ETH received
     * receive() external payable;
     */
}


// File contracts/Interfaces/IZEROStaking.sol



pragma solidity 0.6.11;

interface IZEROStaking {
    // --- Events --

    event ZEROTokenAddressSet(address _zeroTokenAddress);
    event ZUSDTokenAddressSet(address _zusdTokenAddress);
    event FeeDistributorAddressAddressSet(address _feeDistributorAddress);
    event ActivePoolAddressSet(address _activePoolAddress);

    event StakeChanged(address indexed staker, uint256 newStake);
    event StakingGainsWithdrawn(address indexed staker, uint256 ZUSDGain, uint256 ETHGain);
    event F_ETHUpdated(uint256 _F_ETH);
    event F_ZUSDUpdated(uint256 _F_ZUSD);
    event TotalZEROStakedUpdated(uint256 _totalZEROStaked);
    event EtherSent(address _account, uint256 _amount);
    event StakerSnapshotsUpdated(address _staker, uint256 _F_ETH, uint256 _F_ZUSD);

    // --- Functions ---

    /**
     * @notice Called only once on init, to set addresses of other Zero contracts. Callable only by owner
     * @dev initializer function, checks addresses are contracts
     * @param _zeroTokenAddress ZEROToken contract address
     * @param _zusdTokenAddress ZUSDToken contract address
     * @param _feeDistributorAddress FeeDistributorAddress contract address
     * @param _activePoolAddress ActivePool contract address
     */
    function setAddresses(
        address _zeroTokenAddress,
        address _zusdTokenAddress,
        address _feeDistributorAddress,
        address _activePoolAddress
    ) external;

    /// @notice If caller has a pre-existing stake, send any accumulated ETH and ZUSD gains to them.
    /// @param _ZEROamount ZERO tokens to stake
    function stake(uint256 _ZEROamount) external;

    /**
     * @notice Unstake the ZERO and send the it back to the caller, along with their accumulated ZUSD & ETH gains.
     * If requested amount > stake, send their entire stake.
     * @param _ZEROamount ZERO tokens to unstake
     */
    function unstake(uint256 _ZEROamount) external;

    /// @param _ETHFee ETH fee
    /// @notice increase ETH fee
    function increaseF_ETH(uint256 _ETHFee) external;

    /// @param _ZEROFee ZUSD fee
    /// @notice increase ZUSD fee
    function increaseF_ZUSD(uint256 _ZEROFee) external;

    /// @param _user user address
    /// @return pending ETH gain of given user
    function getPendingETHGain(address _user) external view returns (uint256);

    /// @param _user user address
    /// @return pending ZUSD gain of given user
    function getPendingZUSDGain(address _user) external view returns (uint256);
}


// File contracts/Dependencies/IERC20.sol



pragma solidity 0.6.11;

/**
 * Based on the OpenZeppelin IER20 interface:
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol
 *
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


// File contracts/Dependencies/IERC2612.sol



pragma solidity 0.6.11;

/**
 * @dev Interface of the ERC2612 standard as defined in the EIP.
 *
 * Adds the {permit} method, which can be used to change one's
 * {IERC20-allowance} without having to send a transaction, by signing a
 * message. This allows users to spend tokens without having to hold Ether.
 *
 * See https://eips.ethereum.org/EIPS/eip-2612.
 * 
 * Code adapted from https://github.com/OpenZeppelin/openzeppelin-contracts/pull/2237/
 */
interface IERC2612 {
    /**
     * @dev Sets `amount` as the allowance of `spender` over `owner`'s tokens,
     * given `owner`'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(address owner, address spender, uint256 amount, 
                    uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    
    /**
     * @dev Returns the current ERC2612 nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases `owner`'s nonce by one. This
     * prevents a signature from being used multiple times.
     *
     * `owner` can limit the time a Permit is valid for by setting `deadline` to 
     * a value in the near future. The deadline argument can be set to uint(-1) to 
     * create Permits that effectively never expire.
     */
    function nonces(address owner) external view returns (uint256);
    
    function version() external view returns (string memory);
    function permitTypeHash() external view returns (bytes32);
    function domainSeparator() external view returns (bytes32);
}


// File contracts/Interfaces/IZEROToken.sol



pragma solidity 0.6.11;


interface IZEROToken is IERC20, IERC2612 { 

    // --- Functions ---

    /// @notice send zero tokens to ZEROStaking contract
    /// @param _sender sender address
    /// @param _amount amount to send
    function sendToZEROStaking(address _sender, uint256 _amount) external;

    /// @return deployment start time
    function getDeploymentStartTime() external view returns (uint256);

}


// File contracts/Interfaces/IZUSDToken.sol



pragma solidity 0.6.11;


interface IZUSDToken is IERC20, IERC2612 { 
    
    // --- Events ---

    event TroveManagerAddressChanged(address _troveManagerAddress);
    event StabilityPoolAddressChanged(address _newStabilityPoolAddress);
    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);

    event ZUSDTokenBalanceUpdated(address _user, uint _amount);

    // --- Functions ---

    function mint(address _account, uint256 _amount) external;

    function burn(address _account, uint256 _amount) external;

    function sendToPool(address _sender,  address poolAddress, uint256 _amount) external;

    function returnFromPool(address poolAddress, address user, uint256 _amount ) external;
}


// File contracts/Interfaces/ITroveManager.sol



pragma solidity 0.6.11;







/// Common interface for the Trove Manager.
interface ITroveManager is ILiquityBase {
    // --- Events ---

    event FeeDistributorAddressChanged(address _feeDistributorAddress);
    event TroveManagerRedeemOpsAddressChanged(address _troveManagerRedeemOps);
    event LiquityBaseParamsAddressChanges(address _borrowerOperationsAddress);
    event BorrowerOperationsAddressChanged(address _newBorrowerOperationsAddress);
    event PriceFeedAddressChanged(address _newPriceFeedAddress);
    event ZUSDTokenAddressChanged(address _newZUSDTokenAddress);
    event ActivePoolAddressChanged(address _activePoolAddress);
    event DefaultPoolAddressChanged(address _defaultPoolAddress);
    event StabilityPoolAddressChanged(address _stabilityPoolAddress);
    event GasPoolAddressChanged(address _gasPoolAddress);
    event CollSurplusPoolAddressChanged(address _collSurplusPoolAddress);
    event SortedTrovesAddressChanged(address _sortedTrovesAddress);
    event ZEROTokenAddressChanged(address _zeroTokenAddress);
    event ZEROStakingAddressChanged(address _zeroStakingAddress);

    event Liquidation(
        uint256 _liquidatedDebt,
        uint256 _liquidatedColl,
        uint256 _collGasCompensation,
        uint256 _ZUSDGasCompensation
    );
    event Redemption(
        uint256 _attemptedZUSDAmount,
        uint256 _actualZUSDAmount,
        uint256 _ETHSent,
        uint256 _ETHFee
    );
    event TroveUpdated(
        address indexed _borrower,
        uint256 _debt,
        uint256 _coll,
        uint256 stake,
        uint8 operation
    );
    event TroveLiquidated(
        address indexed _borrower,
        uint256 _debt,
        uint256 _coll,
        uint8 operation
    );
    event BaseRateUpdated(uint256 _baseRate);
    event LastFeeOpTimeUpdated(uint256 _lastFeeOpTime);
    event TotalStakesUpdated(uint256 _newTotalStakes);
    event SystemSnapshotsUpdated(uint256 _totalStakesSnapshot, uint256 _totalCollateralSnapshot);
    event LTermsUpdated(uint256 _L_ETH, uint256 _L_ZUSDDebt);
    event TroveSnapshotsUpdated(uint256 _L_ETH, uint256 _L_ZUSDDebt);
    event TroveIndexUpdated(address _borrower, uint256 _newIndex);

    struct TroveManagerInitAddressesParams {
        address _feeDistributorAddress;
        address _troveManagerRedeemOps;
        address _liquityBaseParamsAddress;
        address _borrowerOperationsAddress;
        address _activePoolAddress;
        address _defaultPoolAddress;
        address _stabilityPoolAddress;
        address _gasPoolAddress;
        address _collSurplusPoolAddress;
        address _priceFeedAddress;
        address _zusdTokenAddress;
        address _sortedTrovesAddress;
        address _zeroTokenAddress;
        address _zeroStakingAddress;
    }

    // --- Functions ---
    /**
     * @notice Called only once on init, to set addresses of other Zero contracts. Callable only by owner
     * @dev initializer function, checks addresses are contracts
     * @param _troveManagerInitAddresses addresses list to intialize TroveManager with _
     *        _feeDistributorAddress feeDistributor contract address
     *        _troveManagerRedeemOps TroveManagerRedeemOps contract address
     *        _liquityBaseParamsAddress LiquityBaseParams contract address
     *        _borrowerOperationsAddress BorrowerOperations contract address
     *        _activePoolAddress ActivePool contract address
     *        _defaultPoolAddress DefaultPool contract address
     *        _stabilityPoolAddress StabilityPool contract address
     *        _gasPoolAddress GasPool contract address
     *        _collSurplusPoolAddress CollSurplusPool contract address
     *        _priceFeedAddress PriceFeed contract address
     *        _zusdTokenAddress ZUSDToken contract address
     *        _sortedTrovesAddress SortedTroves contract address
     *        _zeroTokenAddress ZEROToken contract address
     *        _zeroStakingAddress ZEROStaking contract address
     */
    function setAddresses(
        TroveManagerInitAddressesParams memory _troveManagerInitAddresses
    ) external;

    function setTroveManagerRedeemOps(address _troveManagerRedeemOps) external;

    /// @return Trove owners count
    function getTroveOwnersCount() external view returns (uint256);

    /// @param _index Trove owner index
    /// @return Trove from TroveOwners array in given index
    function getTroveFromTroveOwnersArray(uint256 _index) external view returns (address);

    /// @param _borrower borrower address
    /// @return the nominal collateral ratio (ICR) of a given Trove, without the price. Takes a trove's pending coll and debt rewards from redistributions into account.
    function getNominalICR(address _borrower) external view returns (uint256);

    /// @notice computes the user’s individual collateralization ratio (ICR) based on their total collateral and total ZUSD debt. Returns 2^256 -1 if they have 0 debt.
    /// @param _borrower borrower address
    /// @param _price ETH price
    /// @return the current collateral ratio (ICR) of a given Trove. Takes a trove's pending coll and debt rewards from redistributions into account.
    function getCurrentICR(address _borrower, uint256 _price) external view returns (uint256);

    /// @notice Closes the trove if its ICR is lower than the minimum collateral ratio.
    /// @param _borrower borrower address
    function liquidate(address _borrower) external;

    /**
     * @notice Liquidate a sequence of troves. Closes a maximum number of n under-collateralized Troves,
     * starting from the one with the lowest collateral ratio in the system, and moving upwards
     * @param _n max number of under-collateralized Troves to liquidate
     */
    function liquidateTroves(uint256 _n) external;

    /**
     * @notice Attempt to liquidate a custom list of troves provided by the caller.
     * @param _troveArray list of trove addresses
     */
    function batchLiquidateTroves(address[] calldata _troveArray) external;

    /**
     * @notice Send _ZUSDamount ZUSD to the system and redeem the corresponding amount of collateral from as many Troves as are needed to fill the redemption
     * request.  Applies pending rewards to a Trove before reducing its debt and coll.
     *
     * Note that if _amount is very large, this function can run out of gas, specially if traversed troves are small. This can be easily avoided by
     * splitting the total _amount in appropriate chunks and calling the function multiple times.
     *
     * Param `_maxIterations` can also be provided, so the loop through Troves is capped (if it’s zero, it will be ignored).This makes it easier to
     * avoid OOG for the frontend, as only knowing approximately the average cost of an iteration is enough, without needing to know the “topology”
     * of the trove list. It also avoids the need to set the cap in stone in the contract, nor doing gas calculations, as both gas price and opcode
     * costs can vary.
     *
     * All Troves that are redeemed from -- with the likely exception of the last one -- will end up with no debt left, therefore they will be closed.
     * If the last Trove does have some remaining debt, it has a finite ICR, and the reinsertion could be anywhere in the list, therefore it requires a hint.
     * A frontend should use getRedemptionHints() to calculate what the ICR of this Trove will be after redemption, and pass a hint for its position
     * in the sortedTroves list along with the ICR value that the hint was found for.
     *
     * If another transaction modifies the list between calling getRedemptionHints() and passing the hints to redeemCollateral(), it
     * is very likely that the last (partially) redeemed Trove would end up with a different ICR than what the hint is for. In this case the
     * redemption will stop after the last completely redeemed Trove and the sender will keep the remaining ZUSD amount, which they can attempt
     * to redeem later.
     *
     * @param _ZUSDAmount ZUSD amount to send to the system
     * @param _firstRedemptionHint calculated ICR hint of first trove after redemption
     * @param _maxIterations max Troves iterations (can be 0)
     * @param _maxFee max fee percentage to accept
     */
    function redeemCollateral(
        uint256 _ZUSDAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR,
        uint256 _maxIterations,
        uint256 _maxFee
    ) external;

    function redeemCollateralViaDLLR(
        uint256 _dllrAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR,
        uint256 _maxIterations,
        uint256 _maxFeePercentage,
        IMassetManager.PermitParams calldata _permitParams
    ) external;

    /// @notice Update borrower's stake based on their latest collateral value
    /// @param _borrower borrower address
    function updateStakeAndTotalStakes(address _borrower) external returns (uint256);

    /// @notice Update borrower's snapshots of L_ETH and L_ZUSDDebt to reflect the current values
    /// @param _borrower borrower address
    function updateTroveRewardSnapshots(address _borrower) external;

    /// @notice Push the owner's address to the Trove owners list, and record the corresponding array index on the Trove struct
    /// @param _borrower borrower address
    /// @return index where Trove was inserted
    function addTroveOwnerToArray(address _borrower) external returns (uint256 index);

    /// @notice Add the borrowers's coll and debt rewards earned from redistributions, to their Trove
    /// @param _borrower borrower address
    function applyPendingRewards(address _borrower) external;

    /// @param _borrower borrower address
    /// @return the borrower's pending accumulated ETH reward, earned by their stake
    function getPendingETHReward(address _borrower) external view returns (uint256);

    /// @param _borrower borrower address
    /// @return the borrower's pending accumulated ZUSD reward, earned by their stake
    function getPendingZUSDDebtReward(address _borrower) external view returns (uint256);

    /*
     * @notice A Trove has pending rewards if its snapshot is less than the current rewards per-unit-staked sum:
     * this indicates that rewards have occured since the snapshot was made, and the user therefore has
     * pending rewards
     *
     * @param _borrower borrower address
     * @return true if has pending rewards
     */
    function hasPendingRewards(address _borrower) external view returns (bool);

    /// @notice returns the Troves entire debt and coll, including pending rewards from redistributions.
    /// @param _borrower borrower address
    function getEntireDebtAndColl(
        address _borrower
    )
        external
        view
        returns (
            uint256 debt,
            uint256 coll,
            uint256 pendingZUSDDebtReward,
            uint256 pendingETHReward
        );

    /// @notice Close given trove. Called by BorrowerOperations.
    /// @param _borrower borrower address
    function closeTrove(address _borrower) external;

    /// @notice Remove borrower's stake from the totalStakes sum, and set their stake to 0
    /// @param _borrower borrower address
    function removeStake(address _borrower) external;

    /// @return calculated redemption rate using baseRate
    function getRedemptionRate() external view returns (uint256);

    /// @return calculated redemption rate using calculated decayed as base rate
    function getRedemptionRateWithDecay() external view returns (uint256);

    /// @notice The redemption fee is taken as a cut of the total ETH drawn from the system in a redemption. It is based on the current redemption rate.
    /// @param _ETHDrawn ETH drawn
    function getRedemptionFeeWithDecay(uint256 _ETHDrawn) external view returns (uint256);

    /// @return borrowing rate
    function getBorrowingRate() external view returns (uint256);

    /// @return borrowing rate calculated using decayed as base rate
    function getBorrowingRateWithDecay() external view returns (uint256);

    /// @param ZUSDDebt ZUSD debt amount to calculate fee
    /// @return borrowing fee using borrowing rate
    function getBorrowingFee(uint256 ZUSDDebt) external view returns (uint256);

    /// @param _ZUSDDebt ZUSD debt amount to calculate fee
    /// @return borrowing fee using borrowing rate with decay
    function getBorrowingFeeWithDecay(uint256 _ZUSDDebt) external view returns (uint256);

    /// @notice Updates the baseRate state variable based on time elapsed since the last redemption or ZUSD borrowing operation.
    function decayBaseRateFromBorrowing() external;

    /// @param _borrower borrower address
    /// @return Trove status from given trove
    function getTroveStatus(address _borrower) external view returns (uint256);

    /// @param _borrower borrower address
    /// @return Trove stake from given trove
    function getTroveStake(address _borrower) external view returns (uint256);

    /// @param _borrower borrower address
    /// @return Trove debt from given trove
    function getTroveDebt(address _borrower) external view returns (uint256);

    /// @param _borrower borrower address
    /// @return Trove collateral from given trove
    function getTroveColl(address _borrower) external view returns (uint256);

    /// @param _borrower borrower address
    /// @param num status to set
    function setTroveStatus(address _borrower, uint256 num) external;

    /// @param _borrower borrower address
    /// @param _collIncrease amount of collateral to increase
    /// @return new trove collateral
    function increaseTroveColl(
        address _borrower,
        uint256 _collIncrease
    ) external returns (uint256);

    /// @param _borrower borrower address
    /// @param _collDecrease amount of collateral to decrease
    /// @return new trove collateral
    function decreaseTroveColl(
        address _borrower,
        uint256 _collDecrease
    ) external returns (uint256);

    /// @param _borrower borrower address
    /// @param _debtIncrease amount of debt to increase
    /// @return new trove debt
    function increaseTroveDebt(
        address _borrower,
        uint256 _debtIncrease
    ) external returns (uint256);

    /// @param _borrower borrower address
    /// @param _debtDecrease amount of debt to decrease
    /// @return new trove debt
    function decreaseTroveDebt(
        address _borrower,
        uint256 _debtDecrease
    ) external returns (uint256);

    /**
     * @param _price ETH price
     * @return the total collateralization ratio (TCR) of the system.
     * The TCR is based on the the entire system debt and collateral (including pending rewards).
     */
    function getTCR(uint256 _price) external view returns (uint256);

    function MCR() external view returns (uint256);

    function CCR() external view returns (uint256);

    /// @notice reveals whether or not the system is in Recovery Mode (i.e. whether the Total Collateralization Ratio (TCR) is below the Critical Collateralization Ratio (CCR)).
    function checkRecoveryMode(uint256 _price) external view returns (bool);
}


// File contracts/BorrowerOperationsStorage.sol



pragma solidity 0.6.11;










contract BorrowerOperationsStorage is Ownable {
    string public constant NAME = "BorrowerOperations";

    // --- Connected contract declarations ---

    ITroveManager public troveManager;

    address stabilityPoolAddress;

    address gasPoolAddress;

    ICollSurplusPool collSurplusPool;

    IZEROStaking public zeroStaking;
    address public zeroStakingAddress;

    IZUSDToken public zusdToken;

    // A doubly linked list of Troves, sorted by their collateral ratios
    ISortedTroves public sortedTroves;

    IMassetManager public massetManager;
    IFeeDistributor public feeDistributor;
}


// File contracts/Dependencies/CheckContract.sol



pragma solidity 0.6.11;


contract CheckContract {
    /**
     * @dev Check that the account is an already deployed non-destroyed contract.
     * See: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol#L12
     */
    function checkContract(address _account) internal view {
        require(_account != address(0), "Account cannot be zero address");

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(_account) }
        require(size > 0, "Account code size cannot be zero");
    }
}


// File contracts/Dependencies/console.sol



pragma solidity 0.6.11;

// Buidler's helper contract for console logging
library console {
        address constant CONSOLE_ADDRESS = address(0x000000000000000000636F6e736F6c652e6c6f67);

        function log() internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log()"));
                ignored;
        }       function logInt(int p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(int)", p0));
                ignored;
        }

        function logUint(uint p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint)", p0));
                ignored;
        }

        function logString(string memory p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string)", p0));
                ignored;
        }

        function logBool(bool p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool)", p0));
                ignored;
        }

        function logAddress(address p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address)", p0));
                ignored;
        }

        function logBytes(bytes memory p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes)", p0));
                ignored;
        }

        function logByte(byte p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(byte)", p0));
                ignored;
        }

        function logBytes1(bytes1 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes1)", p0));
                ignored;
        }

        function logBytes2(bytes2 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes2)", p0));
                ignored;
        }

        function logBytes3(bytes3 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes3)", p0));
                ignored;
        }

        function logBytes4(bytes4 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes4)", p0));
                ignored;
        }

        function logBytes5(bytes5 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes5)", p0));
                ignored;
        }

        function logBytes6(bytes6 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes6)", p0));
                ignored;
        }

        function logBytes7(bytes7 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes7)", p0));
                ignored;
        }

        function logBytes8(bytes8 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes8)", p0));
                ignored;
        }

        function logBytes9(bytes9 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes9)", p0));
                ignored;
        }

        function logBytes10(bytes10 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes10)", p0));
                ignored;
        }

        function logBytes11(bytes11 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes11)", p0));
                ignored;
        }

        function logBytes12(bytes12 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes12)", p0));
                ignored;
        }

        function logBytes13(bytes13 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes13)", p0));
                ignored;
        }

        function logBytes14(bytes14 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes14)", p0));
                ignored;
        }

        function logBytes15(bytes15 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes15)", p0));
                ignored;
        }

        function logBytes16(bytes16 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes16)", p0));
                ignored;
        }

        function logBytes17(bytes17 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes17)", p0));
                ignored;
        }

        function logBytes18(bytes18 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes18)", p0));
                ignored;
        }

        function logBytes19(bytes19 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes19)", p0));
                ignored;
        }

        function logBytes20(bytes20 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes20)", p0));
                ignored;
        }

        function logBytes21(bytes21 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes21)", p0));
                ignored;
        }

        function logBytes22(bytes22 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes22)", p0));
                ignored;
        }

        function logBytes23(bytes23 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes23)", p0));
                ignored;
        }

        function logBytes24(bytes24 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes24)", p0));
                ignored;
        }

        function logBytes25(bytes25 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes25)", p0));
                ignored;
        }

        function logBytes26(bytes26 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes26)", p0));
                ignored;
        }

        function logBytes27(bytes27 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes27)", p0));
                ignored;
        }

        function logBytes28(bytes28 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes28)", p0));
                ignored;
        }

        function logBytes29(bytes29 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes29)", p0));
                ignored;
        }

        function logBytes30(bytes30 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes30)", p0));
                ignored;
        }

        function logBytes31(bytes31 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes31)", p0));
                ignored;
        }

        function logBytes32(bytes32 p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bytes32)", p0));
                ignored;
        }

        function log(uint p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint)", p0));
                ignored;
        }

        function log(string memory p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string)", p0));
                ignored;
        }

        function log(bool p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool)", p0));
                ignored;
        }

        function log(address p0) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address)", p0));
                ignored;
        }

        function log(uint p0, uint p1) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint)", p0, p1));
                ignored;
        }

        function log(uint p0, string memory p1) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string)", p0, p1));
                ignored;
        }

        function log(uint p0, bool p1) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool)", p0, p1));
                ignored;
        }

        function log(uint p0, address p1) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address)", p0, p1));
                ignored;
        }

        function log(string memory p0, uint p1) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint)", p0, p1));
                ignored;
        }

        function log(string memory p0, string memory p1) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string)", p0, p1));
                ignored;
        }

        function log(string memory p0, bool p1) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool)", p0, p1));
                ignored;
        }

        function log(string memory p0, address p1) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address)", p0, p1));
                ignored;
        }

        function log(bool p0, uint p1) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint)", p0, p1));
                ignored;
        }

        function log(bool p0, string memory p1) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string)", p0, p1));
                ignored;
        }

        function log(bool p0, bool p1) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool)", p0, p1));
                ignored;
        }

        function log(bool p0, address p1) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address)", p0, p1));
                ignored;
        }

        function log(address p0, uint p1) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint)", p0, p1));
                ignored;
        }

        function log(address p0, string memory p1) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string)", p0, p1));
                ignored;
        }

        function log(address p0, bool p1) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool)", p0, p1));
                ignored;
        }

        function log(address p0, address p1) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address)", p0, p1));
                ignored;
        }

        function log(uint p0, uint p1, uint p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,uint)", p0, p1, p2));
                ignored;
        }

        function log(uint p0, uint p1, string memory p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,string)", p0, p1, p2));
                ignored;
        }

        function log(uint p0, uint p1, bool p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,bool)", p0, p1, p2));
                ignored;
        }

        function log(uint p0, uint p1, address p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,address)", p0, p1, p2));
                ignored;
        }

        function log(uint p0, string memory p1, uint p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,uint)", p0, p1, p2));
                ignored;
        }

        function log(uint p0, string memory p1, string memory p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,string)", p0, p1, p2));
                ignored;
        }

        function log(uint p0, string memory p1, bool p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,bool)", p0, p1, p2));
                ignored;
        }

        function log(uint p0, string memory p1, address p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,address)", p0, p1, p2));
                ignored;
        }

        function log(uint p0, bool p1, uint p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,uint)", p0, p1, p2));
                ignored;
        }

        function log(uint p0, bool p1, string memory p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,string)", p0, p1, p2));
                ignored;
        }

        function log(uint p0, bool p1, bool p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,bool)", p0, p1, p2));
                ignored;
        }

        function log(uint p0, bool p1, address p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,address)", p0, p1, p2));
                ignored;
        }

        function log(uint p0, address p1, uint p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,uint)", p0, p1, p2));
                ignored;
        }

        function log(uint p0, address p1, string memory p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,string)", p0, p1, p2));
                ignored;
        }

        function log(uint p0, address p1, bool p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,bool)", p0, p1, p2));
                ignored;
        }

        function log(uint p0, address p1, address p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,address)", p0, p1, p2));
                ignored;
        }

        function log(string memory p0, uint p1, uint p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,uint)", p0, p1, p2));
                ignored;
        }

        function log(string memory p0, uint p1, string memory p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,string)", p0, p1, p2));
                ignored;
        }

        function log(string memory p0, uint p1, bool p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,bool)", p0, p1, p2));
                ignored;
        }

        function log(string memory p0, uint p1, address p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,address)", p0, p1, p2));
                ignored;
        }

        function log(string memory p0, string memory p1, uint p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,uint)", p0, p1, p2));
                ignored;
        }

        function log(string memory p0, string memory p1, string memory p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,string)", p0, p1, p2));
                ignored;
        }

        function log(string memory p0, string memory p1, bool p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,bool)", p0, p1, p2));
                ignored;
        }

        function log(string memory p0, string memory p1, address p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,address)", p0, p1, p2));
                ignored;
        }

        function log(string memory p0, bool p1, uint p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,uint)", p0, p1, p2));
                ignored;
        }

        function log(string memory p0, bool p1, string memory p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,string)", p0, p1, p2));
                ignored;
        }

        function log(string memory p0, bool p1, bool p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,bool)", p0, p1, p2));
                ignored;
        }

        function log(string memory p0, bool p1, address p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,address)", p0, p1, p2));
                ignored;
        }

        function log(string memory p0, address p1, uint p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,uint)", p0, p1, p2));
                ignored;
        }

        function log(string memory p0, address p1, string memory p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,string)", p0, p1, p2));
                ignored;
        }

        function log(string memory p0, address p1, bool p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,bool)", p0, p1, p2));
                ignored;
        }

        function log(string memory p0, address p1, address p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,address)", p0, p1, p2));
                ignored;
        }

        function log(bool p0, uint p1, uint p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,uint)", p0, p1, p2));
                ignored;
        }

        function log(bool p0, uint p1, string memory p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,string)", p0, p1, p2));
                ignored;
        }

        function log(bool p0, uint p1, bool p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,bool)", p0, p1, p2));
                ignored;
        }

        function log(bool p0, uint p1, address p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,address)", p0, p1, p2));
                ignored;
        }

        function log(bool p0, string memory p1, uint p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,uint)", p0, p1, p2));
                ignored;
        }

        function log(bool p0, string memory p1, string memory p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,string)", p0, p1, p2));
                ignored;
        }

        function log(bool p0, string memory p1, bool p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,bool)", p0, p1, p2));
                ignored;
        }

        function log(bool p0, string memory p1, address p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,address)", p0, p1, p2));
                ignored;
        }

        function log(bool p0, bool p1, uint p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,uint)", p0, p1, p2));
                ignored;
        }

        function log(bool p0, bool p1, string memory p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,string)", p0, p1, p2));
                ignored;
        }

        function log(bool p0, bool p1, bool p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,bool)", p0, p1, p2));
                ignored;
        }

        function log(bool p0, bool p1, address p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,address)", p0, p1, p2));
                ignored;
        }

        function log(bool p0, address p1, uint p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,uint)", p0, p1, p2));
                ignored;
        }

        function log(bool p0, address p1, string memory p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,string)", p0, p1, p2));
                ignored;
        }

        function log(bool p0, address p1, bool p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,bool)", p0, p1, p2));
                ignored;
        }

        function log(bool p0, address p1, address p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,address)", p0, p1, p2));
                ignored;
        }

        function log(address p0, uint p1, uint p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,uint)", p0, p1, p2));
                ignored;
        }

        function log(address p0, uint p1, string memory p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,string)", p0, p1, p2));
                ignored;
        }

        function log(address p0, uint p1, bool p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,bool)", p0, p1, p2));
                ignored;
        }

        function log(address p0, uint p1, address p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,address)", p0, p1, p2));
                ignored;
        }

        function log(address p0, string memory p1, uint p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,uint)", p0, p1, p2));
                ignored;
        }

        function log(address p0, string memory p1, string memory p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,string)", p0, p1, p2));
                ignored;
        }

        function log(address p0, string memory p1, bool p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,bool)", p0, p1, p2));
                ignored;
        }

        function log(address p0, string memory p1, address p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,address)", p0, p1, p2));
                ignored;
        }

        function log(address p0, bool p1, uint p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,uint)", p0, p1, p2));
                ignored;
        }

        function log(address p0, bool p1, string memory p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,string)", p0, p1, p2));
                ignored;
        }

        function log(address p0, bool p1, bool p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,bool)", p0, p1, p2));
                ignored;
        }

        function log(address p0, bool p1, address p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,address)", p0, p1, p2));
                ignored;
        }

        function log(address p0, address p1, uint p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,uint)", p0, p1, p2));
                ignored;
        }

        function log(address p0, address p1, string memory p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,string)", p0, p1, p2));
                ignored;
        }

        function log(address p0, address p1, bool p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,bool)", p0, p1, p2));
                ignored;
        }

        function log(address p0, address p1, address p2) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,address)", p0, p1, p2));
                ignored;
        }

        function log(uint p0, uint p1, uint p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,uint,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, uint p1, uint p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,uint,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, uint p1, uint p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,uint,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, uint p1, uint p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,uint,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, uint p1, string memory p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,string,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, uint p1, string memory p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,string,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, uint p1, string memory p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,string,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, uint p1, string memory p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,string,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, uint p1, bool p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,bool,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, uint p1, bool p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,bool,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, uint p1, bool p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,bool,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, uint p1, bool p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,bool,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, uint p1, address p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,address,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, uint p1, address p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,address,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, uint p1, address p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,address,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, uint p1, address p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,uint,address,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, string memory p1, uint p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,uint,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, string memory p1, uint p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,uint,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, string memory p1, uint p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,uint,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, string memory p1, uint p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,uint,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, string memory p1, string memory p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,string,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, string memory p1, string memory p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,string,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, string memory p1, string memory p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,string,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, string memory p1, string memory p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,string,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, string memory p1, bool p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,bool,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, string memory p1, bool p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,bool,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, string memory p1, bool p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,bool,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, string memory p1, bool p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,bool,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, string memory p1, address p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,address,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, string memory p1, address p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,address,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, string memory p1, address p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,address,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, string memory p1, address p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,string,address,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, bool p1, uint p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,uint,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, bool p1, uint p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,uint,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, bool p1, uint p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,uint,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, bool p1, uint p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,uint,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, bool p1, string memory p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,string,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, bool p1, string memory p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,string,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, bool p1, string memory p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,string,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, bool p1, string memory p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,string,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, bool p1, bool p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,bool,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, bool p1, bool p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,bool,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, bool p1, bool p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,bool,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, bool p1, bool p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,bool,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, bool p1, address p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,address,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, bool p1, address p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,address,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, bool p1, address p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,address,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, bool p1, address p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,bool,address,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, address p1, uint p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,uint,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, address p1, uint p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,uint,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, address p1, uint p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,uint,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, address p1, uint p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,uint,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, address p1, string memory p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,string,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, address p1, string memory p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,string,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, address p1, string memory p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,string,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, address p1, string memory p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,string,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, address p1, bool p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,bool,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, address p1, bool p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,bool,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, address p1, bool p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,bool,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, address p1, bool p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,bool,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, address p1, address p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,address,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, address p1, address p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,address,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, address p1, address p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,address,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(uint p0, address p1, address p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(uint,address,address,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, uint p1, uint p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,uint,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, uint p1, uint p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,uint,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, uint p1, uint p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,uint,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, uint p1, uint p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,uint,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, uint p1, string memory p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,string,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, uint p1, string memory p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,string,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, uint p1, string memory p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,string,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, uint p1, string memory p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,string,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, uint p1, bool p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,bool,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, uint p1, bool p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,bool,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, uint p1, bool p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,bool,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, uint p1, bool p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,bool,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, uint p1, address p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,address,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, uint p1, address p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,address,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, uint p1, address p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,address,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, uint p1, address p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,uint,address,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, string memory p1, uint p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,uint,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, string memory p1, uint p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,uint,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, string memory p1, uint p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,uint,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, string memory p1, uint p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,uint,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, string memory p1, string memory p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,string,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, string memory p1, string memory p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,string,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, string memory p1, string memory p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,string,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, string memory p1, string memory p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,string,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, string memory p1, bool p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,bool,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, string memory p1, bool p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,bool,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, string memory p1, bool p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,bool,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, string memory p1, bool p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,bool,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, string memory p1, address p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,address,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, string memory p1, address p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,address,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, string memory p1, address p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,address,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, string memory p1, address p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,string,address,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, bool p1, uint p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,uint,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, bool p1, uint p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,uint,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, bool p1, uint p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,uint,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, bool p1, uint p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,uint,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, bool p1, string memory p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,string,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, bool p1, string memory p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,string,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, bool p1, string memory p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,string,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, bool p1, string memory p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,string,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, bool p1, bool p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,bool,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, bool p1, bool p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,bool,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, bool p1, bool p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,bool,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, bool p1, bool p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,bool,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, bool p1, address p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,address,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, bool p1, address p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,address,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, bool p1, address p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,address,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, bool p1, address p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,bool,address,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, address p1, uint p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,uint,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, address p1, uint p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,uint,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, address p1, uint p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,uint,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, address p1, uint p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,uint,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, address p1, string memory p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,string,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, address p1, string memory p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,string,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, address p1, string memory p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,string,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, address p1, string memory p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,string,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, address p1, bool p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,bool,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, address p1, bool p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,bool,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, address p1, bool p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,bool,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, address p1, bool p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,bool,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, address p1, address p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,address,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, address p1, address p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,address,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, address p1, address p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,address,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(string memory p0, address p1, address p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(string,address,address,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, uint p1, uint p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,uint,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, uint p1, uint p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,uint,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, uint p1, uint p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,uint,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, uint p1, uint p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,uint,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, uint p1, string memory p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,string,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, uint p1, string memory p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,string,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, uint p1, string memory p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,string,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, uint p1, string memory p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,string,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, uint p1, bool p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,bool,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, uint p1, bool p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,bool,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, uint p1, bool p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,bool,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, uint p1, bool p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,bool,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, uint p1, address p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,address,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, uint p1, address p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,address,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, uint p1, address p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,address,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, uint p1, address p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,uint,address,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, string memory p1, uint p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,uint,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, string memory p1, uint p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,uint,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, string memory p1, uint p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,uint,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, string memory p1, uint p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,uint,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, string memory p1, string memory p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,string,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, string memory p1, string memory p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,string,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, string memory p1, string memory p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,string,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, string memory p1, string memory p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,string,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, string memory p1, bool p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,bool,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, string memory p1, bool p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,bool,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, string memory p1, bool p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,bool,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, string memory p1, bool p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,bool,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, string memory p1, address p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,address,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, string memory p1, address p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,address,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, string memory p1, address p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,address,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, string memory p1, address p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,string,address,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, bool p1, uint p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,uint,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, bool p1, uint p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,uint,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, bool p1, uint p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,uint,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, bool p1, uint p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,uint,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, bool p1, string memory p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,string,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, bool p1, string memory p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,string,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, bool p1, string memory p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,string,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, bool p1, string memory p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,string,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, bool p1, bool p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,bool,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, bool p1, bool p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,bool,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, bool p1, bool p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,bool,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, bool p1, bool p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,bool,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, bool p1, address p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,address,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, bool p1, address p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,address,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, bool p1, address p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,address,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, bool p1, address p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,bool,address,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, address p1, uint p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,uint,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, address p1, uint p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,uint,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, address p1, uint p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,uint,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, address p1, uint p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,uint,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, address p1, string memory p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,string,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, address p1, string memory p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,string,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, address p1, string memory p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,string,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, address p1, string memory p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,string,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, address p1, bool p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,bool,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, address p1, bool p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,bool,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, address p1, bool p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,bool,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, address p1, bool p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,bool,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, address p1, address p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,address,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, address p1, address p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,address,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, address p1, address p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,address,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(bool p0, address p1, address p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(bool,address,address,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, uint p1, uint p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,uint,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, uint p1, uint p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,uint,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, uint p1, uint p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,uint,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, uint p1, uint p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,uint,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, uint p1, string memory p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,string,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, uint p1, string memory p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,string,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, uint p1, string memory p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,string,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, uint p1, string memory p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,string,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, uint p1, bool p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,bool,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, uint p1, bool p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,bool,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, uint p1, bool p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,bool,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, uint p1, bool p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,bool,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, uint p1, address p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,address,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, uint p1, address p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,address,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, uint p1, address p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,address,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, uint p1, address p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,uint,address,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, string memory p1, uint p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,uint,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, string memory p1, uint p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,uint,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, string memory p1, uint p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,uint,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, string memory p1, uint p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,uint,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, string memory p1, string memory p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,string,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, string memory p1, string memory p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,string,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, string memory p1, string memory p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,string,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, string memory p1, string memory p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,string,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, string memory p1, bool p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,bool,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, string memory p1, bool p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,bool,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, string memory p1, bool p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,bool,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, string memory p1, bool p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,bool,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, string memory p1, address p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,address,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, string memory p1, address p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,address,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, string memory p1, address p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,address,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, string memory p1, address p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,string,address,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, bool p1, uint p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,uint,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, bool p1, uint p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,uint,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, bool p1, uint p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,uint,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, bool p1, uint p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,uint,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, bool p1, string memory p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,string,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, bool p1, string memory p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,string,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, bool p1, string memory p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,string,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, bool p1, string memory p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,string,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, bool p1, bool p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,bool,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, bool p1, bool p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,bool,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, bool p1, bool p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,bool,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, bool p1, bool p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,bool,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, bool p1, address p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,address,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, bool p1, address p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,address,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, bool p1, address p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,address,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, bool p1, address p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,bool,address,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, address p1, uint p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,uint,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, address p1, uint p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,uint,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, address p1, uint p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,uint,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, address p1, uint p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,uint,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, address p1, string memory p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,string,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, address p1, string memory p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,string,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, address p1, string memory p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,string,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, address p1, string memory p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,string,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, address p1, bool p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,bool,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, address p1, bool p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,bool,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, address p1, bool p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,bool,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, address p1, bool p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,bool,address)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, address p1, address p2, uint p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,address,uint)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, address p1, address p2, string memory p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,address,string)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, address p1, address p2, bool p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,address,bool)", p0, p1, p2, p3));
                ignored;
        }

        function log(address p0, address p1, address p2, address p3) internal view {
                (bool ignored, ) = CONSOLE_ADDRESS.staticcall(abi.encodeWithSignature("log(address,address,address,address)", p0, p1, p2, p3));
                ignored;
        }

}


// File contracts/Dependencies/BaseMath.sol


pragma solidity 0.6.11;


contract BaseMath {
    uint constant public DECIMAL_PRECISION = 1e18;
}


// File contracts/Dependencies/SafeMath.sol



pragma solidity 0.6.11;

/**
 * Based on OpenZeppelin's SafeMath:
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol
 *
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}


// File contracts/Dependencies/LiquityMath.sol



pragma solidity 0.6.11;


library LiquityMath {
    using SafeMath for uint;

    uint internal constant DECIMAL_PRECISION = 1e18;

    /* Precision for Nominal ICR (independent of price). Rationale for the value:
     *
     * - Making it “too high” could lead to overflows.
     * - Making it “too low” could lead to an ICR equal to zero, due to truncation from Solidity floor division. 
     *
     * This value of 1e20 is chosen for safety: the NICR will only overflow for numerator > ~1e39 ETH,
     * and will only truncate to 0 if the denominator is at least 1e20 times greater than the numerator.
     *
     */
    uint internal constant NICR_PRECISION = 1e20;

    function _min(uint _a, uint _b) internal pure returns (uint) {
        return (_a < _b) ? _a : _b;
    }

    function _max(uint _a, uint _b) internal pure returns (uint) {
        return (_a >= _b) ? _a : _b;
    }

    /* 
    * Multiply two decimal numbers and use normal rounding rules:
    * -round product up if 19'th mantissa digit >= 5
    * -round product down if 19'th mantissa digit < 5
    *
    * Used only inside the exponentiation, _decPow().
    */
    function decMul(uint x, uint y) internal pure returns (uint decProd) {
        uint prod_xy = x.mul(y);

        decProd = prod_xy.add(DECIMAL_PRECISION / 2).div(DECIMAL_PRECISION);
    }

    /* 
    * _decPow: Exponentiation function for 18-digit decimal base, and integer exponent n.
    * 
    * Uses the efficient "exponentiation by squaring" algorithm. O(log(n)) complexity. 
    * 
    * Called by two functions that represent time in units of minutes:
    * 1) TroveManager._calcDecayedBaseRate
    * 2) CommunityIssuance._getCumulativeIssuanceFraction 
    * 
    * The exponent is capped to avoid reverting due to overflow. The cap 525600000 equals
    * "minutes in 1000 years": 60 * 24 * 365 * 1000
    * 
    * If a period of > 1000 years is ever used as an exponent in either of the above functions, the result will be
    * negligibly different from just passing the cap, since: 
    *
    * In function 1), the decayed base rate will be 0 for 1000 years or > 1000 years
    * In function 2), the difference in tokens issued at 1000 years and any time > 1000 years, will be negligible
    */
    function _decPow(uint _base, uint _minutes) internal pure returns (uint) {
       
        if (_minutes > 525600000) {_minutes = 525600000;}  // cap to avoid overflow
    
        if (_minutes == 0) {return DECIMAL_PRECISION;}

        uint y = DECIMAL_PRECISION;
        uint x = _base;
        uint n = _minutes;

        // Exponentiation-by-squaring
        while (n > 1) {
            if (n % 2 == 0) {
                x = decMul(x, x);
                n = n.div(2);
            } else { // if (n % 2 != 0)
                y = decMul(x, y);
                x = decMul(x, x);
                n = (n.sub(1)).div(2);
            }
        }

        return decMul(x, y);
  }

    function _getAbsoluteDifference(uint _a, uint _b) internal pure returns (uint) {
        return (_a >= _b) ? _a.sub(_b) : _b.sub(_a);
    }

    function _computeNominalCR(uint _coll, uint _debt) internal pure returns (uint) {
        if (_debt > 0) {
            return _coll.mul(NICR_PRECISION).div(_debt);
        }
        // Return the maximal value for uint256 if the Trove has a debt of 0. Represents "infinite" CR.
        else { // if (_debt == 0)
            return 2**256 - 1;
        }
    }

    function _computeCR(uint _coll, uint _debt, uint _price) internal pure returns (uint) {
        if (_debt > 0) {
            uint newCollRatio = _coll.mul(_price).div(_debt);

            return newCollRatio;
        }
        // Return the maximal value for uint256 if the Trove has a debt of 0. Represents "infinite" CR.
        else { // if (_debt == 0)
            return 2**256 - 1; 
        }
    }
}


// File contracts/Interfaces/IDefaultPool.sol



pragma solidity 0.6.11;

interface IDefaultPool is IPool {
    // --- Events ---
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event DefaultPoolZUSDDebtUpdated(uint256 _ZUSDDebt);
    event DefaultPoolETHBalanceUpdated(uint256 _ETH);

    // --- Functions ---

    /// @notice Send ETH to Active Pool
    /// @param _amount ETH to send
    function sendETHToActivePool(uint256 _amount) external;
}


// File contracts/Dependencies/LiquityBase.sol



pragma solidity 0.6.11;







/**
 * Base contract for TroveManager, BorrowerOperations and StabilityPool. Contains global system constants and
 * common functions.
 */
contract LiquityBase is BaseMath, ILiquityBase {
    using SafeMath for uint256;

    uint256 public constant _100pct = 1000000000000000000; // 1e18 == 100%

    /// Amount of ZUSD to be locked in gas pool on opening troves
    uint256 public constant ZUSD_GAS_COMPENSATION = 20e18;

    /// Minimum amount of net ZUSD debt a trove must have
    uint256 public constant MIN_NET_DEBT = 180e18;

    IActivePool public activePool;

    IDefaultPool public defaultPool;

    IPriceFeed public override priceFeed;

    ILiquityBaseParams public override liquityBaseParams;

    // --- Gas compensation functions ---

    // Returns the composite debt (drawn debt + gas compensation) of a trove, for the purpose of ICR calculation
    function _getCompositeDebt(uint256 _debt) internal pure returns (uint256) {
        return _debt.add(ZUSD_GAS_COMPENSATION);
    }

    function _getNetDebt(uint256 _debt) internal pure returns (uint256) {
        return _debt.sub(ZUSD_GAS_COMPENSATION);
    }

    /// Return the amount of ETH to be drawn from a trove's collateral and sent as gas compensation.
    function _getCollGasCompensation(uint256 _entireColl) internal view returns (uint256) {
        return _entireColl / liquityBaseParams.PERCENT_DIVISOR();
    }

    function getEntireSystemColl() public view returns (uint256 entireSystemColl) {
        uint256 activeColl = activePool.getETH();
        uint256 liquidatedColl = defaultPool.getETH();

        return activeColl.add(liquidatedColl);
    }

    function getEntireSystemDebt() public view returns (uint256 entireSystemDebt) {
        uint256 activeDebt = activePool.getZUSDDebt();
        uint256 closedDebt = defaultPool.getZUSDDebt();

        return activeDebt.add(closedDebt);
    }

    function _getTCR(uint256 _price) internal view returns (uint256 TCR) {
        uint256 entireSystemColl = getEntireSystemColl();
        uint256 entireSystemDebt = getEntireSystemDebt();

        TCR = LiquityMath._computeCR(entireSystemColl, entireSystemDebt, _price);

        return TCR;
    }

    function _checkRecoveryMode(uint256 _price) internal view returns (bool) {
        uint256 TCR = _getTCR(_price);

        return TCR < liquityBaseParams.CCR();
    }

    function _requireUserAcceptsFee(
        uint256 _fee,
        uint256 _amount,
        uint256 _maxFeePercentage
    ) internal pure {
        uint256 feePercentage = _fee.mul(DECIMAL_PRECISION).div(_amount);
        require(feePercentage <= _maxFeePercentage, "Fee exceeded provided maximum");
    }
}


// File contracts/Dependencies/Mynt/IDLLR.sol



pragma solidity 0.6.11;

/// Public interface for Sovryn Dollar DLLR (Meta Asset Token of Sovryn Mynt) exposing specific functions
interface IDLLR is IERC20 {
    /**
     * @notice Only owner can transfer the token.
     * @notice destination cannot be:
     * - zero (0x0) address.
     *
     * @param _recipient Recipient of the token.
     * @param _amount The amount of token that will be transferred.
     *
     * @return true / false.
     */
    function transfer(address _recipient, uint256 _amount) external override returns (bool);

    /**
     * @notice Only owner who can transfer the token.
     * @notice destination cannot be:
     * - zero (0x0) address.
     *
     * @param _from Sender of the token.
     * @param _to Recipient of the token.
     * @param _amount The amount of token that will be transferred.
     *
     * @return true / false.
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) external override returns (bool);

    /**
     * @notice transfer utilizing EIP-2612, to reduce the additional sending transaction for doing the approval to the spender.
     *
     * @notice destination cannot be:
     * - zero (0x0) address.
     *
     * @dev By calling this function, the allowance will be overwritten by the total amount.
     *
     * @param _from Sender of the token.
     * @param _to Recipient of the token.
     * @param _amount The amount of the token that will be transferred.
     * @param _deadline Expiration time of the signature.
     * @param _v Last 1 byte of ECDSA signature.
     * @param _r First 32 bytes of ECDSA signature.
     * @param _s 32 bytes after _r in ECDSA signature.
     */
    function transferWithPermit(
        address _from,
        address _to,
        uint256 _amount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;

    /**
     * @notice Approves and then calls the receiving contract.
     * Useful to encapsulate sending tokens to a contract in one call.
     * Solidity has no native way to send tokens to contracts.
     * ERC-20 tokens require approval to be spent by third parties, such as a contract in this case.
     * @param _spender The contract address to spend the tokens.
     * @param _amount The amount of tokens to be sent.
     * @param _data Parameters for the contract call, such as endpoint signature.
     */
    function approveAndCall(address _spender, uint256 _amount, bytes calldata _data) external;
}


// File contracts/Dependencies/Mynt/MyntLib.sol



pragma solidity 0.6.11;



library MyntLib {
    using SafeMath for uint256;

    /**
     * @notice Convert DLLR _dllrAmount to _toToken utilizing EIP-2612 permit
     * to reduce the additional sending transaction for doing the approval to the spender.
     *
     * @param _myntMassetManager Mynt protocol MassetManager contract address - needed for integration
     * @param _dllrAmount The amount of the DLLR (mAsset) token that will be burned in exchange for _toToken
     * @param _toToken bAsset token address to wothdraw from DLLR
     * @param _permitParams EIP-2612 permit params:
     *        _deadline Expiration time of the signature.
     *        _v Last 1 byte of ECDSA signature.
     *        _r First 32 bytes of ECDSA signature.
     *        _s 32 bytes after _r in ECDSA signature.
     * @return redeemed ZUSD amount
     */
    function redeemZusdFromDllrWithPermit(
        IMassetManager _myntMassetManager,
        uint256 _dllrAmount,
        address _toToken,
        IMassetManager.PermitParams calldata _permitParams
    ) internal returns (uint256) {
        IDLLR dllr = IDLLR(_myntMassetManager.getToken());
        uint256 thisBalanceBefore = dllr.balanceOf(address(this));
        address thisAddress = address(this);
        dllr.transferWithPermit(
            msg.sender,
            thisAddress,
            _dllrAmount,
            _permitParams.deadline,
            _permitParams.v,
            _permitParams.r,
            _permitParams.s
        );
        require(
            dllr.balanceOf(thisAddress).sub(thisBalanceBefore) == _dllrAmount,
            "DLLR transferred amount validation failed"
        );
        return _myntMassetManager.redeemTo(_toToken, _dllrAmount, msg.sender);
    }
}


// File contracts/BorrowerOperations.sol



pragma solidity 0.6.11;













contract BorrowerOperations is
    LiquityBase,
    BorrowerOperationsStorage,
    CheckContract,
    IBorrowerOperations
{
    /* --- Variable container structs  ---

    Used to hold, return and assign variables inside a function, in order to avoid the error:
    "CompilerError: Stack too deep". */

    struct LocalVariables_adjustTrove {
        uint256 price;
        uint256 collChange;
        uint256 netDebtChange;
        bool isCollIncrease;
        uint256 debt;
        uint256 coll;
        uint256 oldICR;
        uint256 newICR;
        uint256 newTCR;
        uint256 ZUSDFee;
        uint256 newDebt;
        uint256 newColl;
        uint256 stake;
        uint256 newNICR;
        bool isRecoveryMode;
    }

    struct LocalVariables_openTrove {
        uint256 price;
        uint256 ZUSDFee;
        uint256 netDebt;
        uint256 compositeDebt;
        uint256 ICR;
        uint256 NICR;
        uint256 stake;
        uint256 arrayIndex;
    }

    struct ContractsCache {
        ITroveManager troveManager;
        IActivePool activePool;
        IZUSDToken zusdToken;
    }

    enum BorrowerOperation {
        openTrove,
        closeTrove,
        adjustTrove
    }

    event FeeDistributorAddressChanged(address _feeDistributorAddress);
    event TroveManagerAddressChanged(address _newTroveManagerAddress);
    event ActivePoolAddressChanged(address _activePoolAddress);
    event DefaultPoolAddressChanged(address _defaultPoolAddress);
    event StabilityPoolAddressChanged(address _stabilityPoolAddress);
    event GasPoolAddressChanged(address _gasPoolAddress);
    event CollSurplusPoolAddressChanged(address _collSurplusPoolAddress);
    event PriceFeedAddressChanged(address _newPriceFeedAddress);
    event SortedTrovesAddressChanged(address _sortedTrovesAddress);
    event ZUSDTokenAddressChanged(address _zusdTokenAddress);
    event ZEROStakingAddressChanged(address _zeroStakingAddress);
    event MassetManagerAddressChanged(address _massetManagerAddress);

    event TroveCreated(address indexed _borrower, uint256 arrayIndex);
    event TroveUpdated(
        address indexed _borrower,
        uint256 _debt,
        uint256 _coll,
        uint256 stake,
        BorrowerOperation operation
    );
    event ZUSDBorrowingFeePaid(address indexed _borrower, uint256 _ZUSDFee);

    // --- Dependency setters ---

    function setAddresses(
        address _feeDistributorAddress,
        address _liquityBaseParamsAddress,
        address _troveManagerAddress,
        address _activePoolAddress,
        address _defaultPoolAddress,
        address _stabilityPoolAddress,
        address _gasPoolAddress,
        address _collSurplusPoolAddress,
        address _priceFeedAddress,
        address _sortedTrovesAddress,
        address _zusdTokenAddress,
        address _zeroStakingAddress
    ) external override onlyOwner {
        // This makes impossible to open a trove with zero withdrawn ZUSD
        assert(MIN_NET_DEBT > 0);

        checkContract(_feeDistributorAddress);
        checkContract(_liquityBaseParamsAddress);
        checkContract(_troveManagerAddress);
        checkContract(_activePoolAddress);
        checkContract(_defaultPoolAddress);
        checkContract(_stabilityPoolAddress);
        checkContract(_gasPoolAddress);
        checkContract(_collSurplusPoolAddress);
        checkContract(_priceFeedAddress);
        checkContract(_sortedTrovesAddress);
        checkContract(_zusdTokenAddress);
        checkContract(_zeroStakingAddress);

        feeDistributor = IFeeDistributor(_feeDistributorAddress);
        liquityBaseParams = ILiquityBaseParams(_liquityBaseParamsAddress);
        troveManager = ITroveManager(_troveManagerAddress);
        activePool = IActivePool(_activePoolAddress);
        defaultPool = IDefaultPool(_defaultPoolAddress);
        stabilityPoolAddress = _stabilityPoolAddress;
        gasPoolAddress = _gasPoolAddress;
        collSurplusPool = ICollSurplusPool(_collSurplusPoolAddress);
        priceFeed = IPriceFeed(_priceFeedAddress);
        sortedTroves = ISortedTroves(_sortedTrovesAddress);
        zusdToken = IZUSDToken(_zusdTokenAddress);
        zeroStakingAddress = _zeroStakingAddress;
        zeroStaking = IZEROStaking(_zeroStakingAddress);

        emit FeeDistributorAddressChanged(_feeDistributorAddress);
        emit TroveManagerAddressChanged(_troveManagerAddress);
        emit ActivePoolAddressChanged(_activePoolAddress);
        emit DefaultPoolAddressChanged(_defaultPoolAddress);
        emit StabilityPoolAddressChanged(_stabilityPoolAddress);
        emit GasPoolAddressChanged(_gasPoolAddress);
        emit CollSurplusPoolAddressChanged(_collSurplusPoolAddress);
        emit PriceFeedAddressChanged(_priceFeedAddress);
        emit SortedTrovesAddressChanged(_sortedTrovesAddress);
        emit ZUSDTokenAddressChanged(_zusdTokenAddress);
        emit ZEROStakingAddressChanged(_zeroStakingAddress);
    }

    function setMassetManagerAddress(address _massetManagerAddress) external onlyOwner {
        massetManager = IMassetManager(_massetManagerAddress);
        emit MassetManagerAddressChanged(_massetManagerAddress);
    }

    function openTrove(
        uint256 _maxFeePercentage,
        uint256 _ZUSDAmount,
        address _upperHint,
        address _lowerHint
    ) external payable override {
        _openTrove(_maxFeePercentage, _ZUSDAmount, _upperHint, _lowerHint, msg.sender);
    }

    function openNueTrove(
        uint256 _maxFeePercentage,
        uint256 _ZUSDAmount,
        address _upperHint,
        address _lowerHint
    ) external payable override {
        require(address(massetManager) != address(0), "Masset address not set");

        _openTrove(_maxFeePercentage, _ZUSDAmount, _upperHint, _lowerHint, address(this));
        require(
            zusdToken.approve(address(massetManager), _ZUSDAmount),
            "Failed to approve ZUSD amount for Mynt mAsset to redeem"
        );
        massetManager.mintTo(address(zusdToken), _ZUSDAmount, msg.sender);
    }

    // --- Borrower Trove Operations ---
    function _openTrove(
        uint256 _maxFeePercentage,
        uint256 _ZUSDAmount,
        address _upperHint,
        address _lowerHint,
        address _tokensRecipient
    ) internal {
        ContractsCache memory contractsCache = ContractsCache(troveManager, activePool, zusdToken);
        LocalVariables_openTrove memory vars;

        vars.price = priceFeed.fetchPrice();
        bool isRecoveryMode = _checkRecoveryMode(vars.price);

        _requireValidMaxFeePercentage(_maxFeePercentage, isRecoveryMode);
        _requireTroveisNotActive(contractsCache.troveManager, msg.sender);

        vars.ZUSDFee;
        vars.netDebt = _ZUSDAmount;

        if (!isRecoveryMode) {
            vars.ZUSDFee = _triggerBorrowingFee(
                contractsCache.troveManager,
                contractsCache.zusdToken,
                _ZUSDAmount,
                _maxFeePercentage
            );
            vars.netDebt = vars.netDebt.add(vars.ZUSDFee);
        }
        _requireAtLeastMinNetDebt(vars.netDebt);

        // ICR is based on the composite debt, i.e. the requested ZUSD amount + ZUSD borrowing fee + ZUSD gas comp.
        vars.compositeDebt = _getCompositeDebt(vars.netDebt);
        assert(vars.compositeDebt > 0);

        vars.ICR = LiquityMath._computeCR(msg.value, vars.compositeDebt, vars.price);
        vars.NICR = LiquityMath._computeNominalCR(msg.value, vars.compositeDebt);

        if (isRecoveryMode) {
            _requireICRisAboveCCR(vars.ICR);
        } else {
            _requireICRisAboveMCR(vars.ICR);
            uint256 newTCR = _getNewTCRFromTroveChange(
                msg.value,
                true,
                vars.compositeDebt,
                true,
                vars.price
            ); // bools: coll increase, debt increase
            _requireNewTCRisAboveCCR(newTCR);
        }

        // Set the trove struct's properties
        contractsCache.troveManager.setTroveStatus(msg.sender, 1);
        contractsCache.troveManager.increaseTroveColl(msg.sender, msg.value);
        contractsCache.troveManager.increaseTroveDebt(msg.sender, vars.compositeDebt);

        contractsCache.troveManager.updateTroveRewardSnapshots(msg.sender);
        vars.stake = contractsCache.troveManager.updateStakeAndTotalStakes(msg.sender);

        sortedTroves.insert(msg.sender, vars.NICR, _upperHint, _lowerHint);
        vars.arrayIndex = contractsCache.troveManager.addTroveOwnerToArray(msg.sender);
        emit TroveCreated(msg.sender, vars.arrayIndex);

        // Move the ether to the Active Pool, and mint the ZUSDAmount to the borrower
        _activePoolAddColl(contractsCache.activePool, msg.value);
        _mintZusdAndIncreaseActivePoolDebt(
            contractsCache.activePool,
            contractsCache.zusdToken,
            _tokensRecipient,
            _ZUSDAmount,
            vars.netDebt
        );
        // Move the ZUSD gas compensation to the Gas Pool
        _mintZusdAndIncreaseActivePoolDebt(
            contractsCache.activePool,
            contractsCache.zusdToken,
            gasPoolAddress,
            ZUSD_GAS_COMPENSATION,
            ZUSD_GAS_COMPENSATION
        );

        emit TroveUpdated(
            msg.sender,
            vars.compositeDebt,
            msg.value,
            vars.stake,
            BorrowerOperation.openTrove
        );
        emit ZUSDBorrowingFeePaid(msg.sender, vars.ZUSDFee);
    }

    /// Send ETH as collateral to a trove
    function addColl(address _upperHint, address _lowerHint) external payable override {
        _adjustTrove(msg.sender, 0, 0, false, _upperHint, _lowerHint, 0);
    }

    /// Send ETH as collateral to a trove. Called by only the Stability Pool.
    function moveETHGainToTrove(
        address _borrower,
        address _upperHint,
        address _lowerHint
    ) external payable override {
        _requireCallerIsStabilityPool();
        _adjustTrove(_borrower, 0, 0, false, _upperHint, _lowerHint, 0);
    }

    /// Withdraw ETH collateral from a trove
    function withdrawColl(
        uint256 _collWithdrawal,
        address _upperHint,
        address _lowerHint
    ) external override {
        _adjustTrove(msg.sender, _collWithdrawal, 0, false, _upperHint, _lowerHint, 0);
    }

    /// Withdraw ZUSD tokens from a trove: mint new ZUSD tokens to the owner, and increase the trove's debt accordingly
    function withdrawZUSD(
        uint256 _maxFeePercentage,
        uint256 _ZUSDAmount,
        address _upperHint,
        address _lowerHint
    ) external override {
        _adjustTrove(msg.sender, 0, _ZUSDAmount, true, _upperHint, _lowerHint, _maxFeePercentage);
    }

    /// Borrow (withdraw) ZUSD tokens from a trove: mint new ZUSD tokens to the owner and convert it to DLLR in one transaction
    /// Zero Line of Credit owner can borrow a specified amount of ZUSD and convert it to DLLR via Sovryn Mynt
    ///@return DLLR amount minted
    function withdrawZusdAndConvertToDLLR(
        uint256 _maxFeePercentage,
        uint256 _ZUSDAmount,
        address _upperHint,
        address _lowerHint
    ) external override returns (uint256) {
        address thisAddress = address(this);
        uint256 balanceBefore = zusdToken.balanceOf(thisAddress);

        _withdrawZusdTo(
            msg.sender,
            thisAddress,
            _ZUSDAmount,
            _upperHint,
            _lowerHint,
            _maxFeePercentage
        );

        require(
            zusdToken.balanceOf(thisAddress) == balanceBefore.add(_ZUSDAmount),
            "ZUSD is not borrowed correctly"
        );
        require(
            zusdToken.approve(address(massetManager), _ZUSDAmount),
            "Failed to approve ZUSD amount for Mynt mAsset to redeem"
        );
        return massetManager.mintTo(address(zusdToken), _ZUSDAmount, msg.sender);
    }

    /// Repay ZUSD tokens to a Trove: Burn the repaid ZUSD tokens, and reduce the trove's debt accordingly
    function repayZUSD(
        uint256 _ZUSDAmount,
        address _upperHint,
        address _lowerHint
    ) external override {
        _adjustTrove(msg.sender, 0, _ZUSDAmount, false, _upperHint, _lowerHint, 0);
    }

    /// Repay ZUSD tokens to a Trove by DLLR: convert DLLR to ZUSD tokens, and then reduce the trove's debt accordingly
    function repayZusdFromDLLR(
        uint256 _dllrAmount,
        address _upperHint,
        address _lowerHint,
        IMassetManager.PermitParams calldata _permitParams
    ) external override {
        _adjustNueTrove(0, 0, _dllrAmount, false, _upperHint, _lowerHint, _permitParams);
    }

    function adjustTrove(
        uint256 _maxFeePercentage,
        uint256 _collWithdrawal,
        uint256 _ZUSDChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external payable override {
        _adjustTrove(
            msg.sender,
            _collWithdrawal,
            _ZUSDChange,
            _isDebtIncrease,
            _upperHint,
            _lowerHint,
            _maxFeePercentage
        );
    }

    // in case of _isDebtIncrease = false MassetManager contract must have an approval of NUE tokens
    function adjustNueTrove(
        uint256 _maxFeePercentage,
        uint256 _collWithdrawal,
        uint256 _ZUSDChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint,
        IMassetManager.PermitParams calldata _permitParams
    ) external payable override {
        _adjustNueTrove(
            _maxFeePercentage,
            _collWithdrawal,
            _ZUSDChange,
            _isDebtIncrease,
            _upperHint,
            _lowerHint,
            _permitParams
        );
    }

    // in case of _isDebtIncrease = false Masset Manager contract must have an approval of NUE tokens
    function _adjustNueTrove(
        uint256 _maxFeePercentage,
        uint256 _collWithdrawal,
        uint256 _ZUSDChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint,
        IMassetManager.PermitParams calldata _permitParams
    ) internal {
        require(address(massetManager) != address(0), "Masset address not set");

        if (!_isDebtIncrease && _ZUSDChange > 0) {
            MyntLib.redeemZusdFromDllrWithPermit(
                massetManager,
                _ZUSDChange,
                address(zusdToken),
                _permitParams
            );
        }
        _adjustSenderTrove(
            msg.sender,
            _collWithdrawal,
            _ZUSDChange,
            _isDebtIncrease,
            _upperHint,
            _lowerHint,
            _maxFeePercentage,
            address(this)
        );
        if (_isDebtIncrease && _ZUSDChange > 0) {
            require(
                zusdToken.approve(address(massetManager), _ZUSDChange),
                "Failed to approve ZUSD amount for Mynt mAsset to redeem"
            );
            massetManager.mintTo(address(zusdToken), _ZUSDChange, msg.sender);
        }
    }

    function _adjustTrove(
        address _borrower,
        uint256 _collWithdrawal,
        uint256 _ZUSDChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint,
        uint256 _maxFeePercentage
    ) internal {
        _adjustSenderTrove(
            _borrower,
            _collWithdrawal,
            _ZUSDChange,
            _isDebtIncrease,
            _upperHint,
            _lowerHint,
            _maxFeePercentage,
            msg.sender
        );
    }

    // _withdrawZusd: _adjustTrove(msg.sender, 0, _ZUSDAmount, true, _upperHint, _lowerHint, _maxFeePercentage);
    function _withdrawZusdTo(
        address _borrower,
        address _receiver,
        uint256 _ZUSDChange,
        address _upperHint,
        address _lowerHint,
        uint256 _maxFeePercentage
    ) internal {
        _adjustSenderTrove(
            _borrower,
            0,
            _ZUSDChange,
            true,
            _upperHint,
            _lowerHint,
            _maxFeePercentage,
            _receiver
        );
    }

    /**
     * _adjustSenderTrove(): Alongside a debt change, this function can perform either a collateral top-up or a collateral withdrawal.
     *
     * It therefore expects either a positive msg.value, or a positive _collWithdrawal argument.
     *
     * If both are positive, it will revert.
     */
    function _adjustSenderTrove(
        address _borrower,
        uint256 _collWithdrawal,
        uint256 _ZUSDChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint,
        uint256 _maxFeePercentage,
        address _tokensRecipient
    ) internal {
        ContractsCache memory contractsCache = ContractsCache(troveManager, activePool, zusdToken);
        LocalVariables_adjustTrove memory vars;

        vars.price = priceFeed.fetchPrice();
        vars.isRecoveryMode = _checkRecoveryMode(vars.price);

        if (_isDebtIncrease) {
            _requireValidMaxFeePercentage(_maxFeePercentage, vars.isRecoveryMode);
            _requireNonZeroDebtChange(_ZUSDChange);
        }
        _requireSingularCollChange(_collWithdrawal);
        _requireNonZeroAdjustment(_collWithdrawal, _ZUSDChange);
        _requireTroveisActive(contractsCache.troveManager, _borrower);

        // Confirm the operation is either a borrower adjusting their own trove, or a pure ETH transfer from the Stability Pool to a trove
        assert(
            msg.sender == _borrower ||
                (msg.sender == stabilityPoolAddress && msg.value > 0 && _ZUSDChange == 0)
        );

        contractsCache.troveManager.applyPendingRewards(_borrower);

        // Get the collChange based on whether or not ETH was sent in the transaction
        (vars.collChange, vars.isCollIncrease) = _getCollChange(msg.value, _collWithdrawal);

        vars.netDebtChange = _ZUSDChange;

        // If the adjustment incorporates a debt increase and system is in Normal Mode, then trigger a borrowing fee
        if (_isDebtIncrease && !vars.isRecoveryMode) {
            vars.ZUSDFee = _triggerBorrowingFee(
                contractsCache.troveManager,
                contractsCache.zusdToken,
                _ZUSDChange,
                _maxFeePercentage
            );
            vars.netDebtChange = vars.netDebtChange.add(vars.ZUSDFee); // The raw debt change includes the fee
        }

        vars.debt = contractsCache.troveManager.getTroveDebt(_borrower);
        vars.coll = contractsCache.troveManager.getTroveColl(_borrower);

        // Get the trove's old ICR before the adjustment, and what its new ICR will be after the adjustment
        vars.oldICR = LiquityMath._computeCR(vars.coll, vars.debt, vars.price);
        vars.newICR = _getNewICRFromTroveChange(
            vars.coll,
            vars.debt,
            vars.collChange,
            vars.isCollIncrease,
            vars.netDebtChange,
            _isDebtIncrease,
            vars.price
        );
        assert(_collWithdrawal <= vars.coll);

        // Check the adjustment satisfies all conditions for the current system mode
        _requireValidAdjustmentInCurrentMode(
            vars.isRecoveryMode,
            _collWithdrawal,
            _isDebtIncrease,
            vars
        );

        // When the adjustment is a debt repayment, check it's a valid amount and that the caller has enough ZUSD
        if (!_isDebtIncrease && _ZUSDChange > 0) {
            _requireAtLeastMinNetDebt(_getNetDebt(vars.debt).sub(vars.netDebtChange));
            _requireValidZUSDRepayment(vars.debt, vars.netDebtChange);
            _requireSufficientZUSDBalance(contractsCache.zusdToken, _borrower, vars.netDebtChange);
        }

        (vars.newColl, vars.newDebt) = _updateTroveFromAdjustment(
            contractsCache.troveManager,
            _borrower,
            vars.collChange,
            vars.isCollIncrease,
            vars.netDebtChange,
            _isDebtIncrease
        );
        vars.stake = contractsCache.troveManager.updateStakeAndTotalStakes(_borrower);

        // Re-insert trove in to the sorted list
        vars.newNICR = _getNewNominalICRFromTroveChange(
            vars.coll,
            vars.debt,
            vars.collChange,
            vars.isCollIncrease,
            vars.netDebtChange,
            _isDebtIncrease
        );
        sortedTroves.reInsert(_borrower, vars.newNICR, _upperHint, _lowerHint);

        emit TroveUpdated(
            _borrower,
            vars.newDebt,
            vars.newColl,
            vars.stake,
            BorrowerOperation.adjustTrove
        );
        emit ZUSDBorrowingFeePaid(msg.sender, vars.ZUSDFee);

        // Use the unmodified _ZUSDChange here, as we don't send the fee to the user
        _moveTokensAndETHfromAdjustment(
            contractsCache.activePool,
            contractsCache.zusdToken,
            msg.sender,
            vars.collChange,
            vars.isCollIncrease,
            _ZUSDChange,
            _isDebtIncrease,
            vars.netDebtChange,
            _tokensRecipient
        );
    }

    function closeTrove() external override {
        _closeTrove();
    }

    function closeNueTrove(IMassetManager.PermitParams calldata _permitParams) external override {
        require(address(massetManager) != address(0), "Masset address not set");

        uint256 debt = troveManager.getTroveDebt(msg.sender);

        MyntLib.redeemZusdFromDllrWithPermit(
            massetManager,
            debt.sub(ZUSD_GAS_COMPENSATION),
            address(zusdToken),
            _permitParams
        );
        _closeTrove();
    }

    function _closeTrove() internal {
        ITroveManager troveManagerCached = troveManager;
        IActivePool activePoolCached = activePool;
        IZUSDToken zusdTokenCached = zusdToken;

        _requireTroveisActive(troveManagerCached, msg.sender);
        uint256 price = priceFeed.fetchPrice();
        _requireNotInRecoveryMode(price);

        troveManagerCached.applyPendingRewards(msg.sender);

        uint256 coll = troveManagerCached.getTroveColl(msg.sender);
        uint256 debt = troveManagerCached.getTroveDebt(msg.sender);

        _requireSufficientZUSDBalance(
            zusdTokenCached,
            msg.sender,
            debt.sub(ZUSD_GAS_COMPENSATION)
        );

        uint256 newTCR = _getNewTCRFromTroveChange(coll, false, debt, false, price);
        _requireNewTCRisAboveCCR(newTCR);

        troveManagerCached.removeStake(msg.sender);
        troveManagerCached.closeTrove(msg.sender);

        emit TroveUpdated(msg.sender, 0, 0, 0, BorrowerOperation.closeTrove);

        // Burn the repaid ZUSD from the user's balance and the gas compensation from the Gas Pool
        _burnZusdAndDecreaseActivePoolDebt(
            activePoolCached,
            zusdTokenCached,
            msg.sender,
            debt.sub(ZUSD_GAS_COMPENSATION)
        );
        _burnZusdAndDecreaseActivePoolDebt(
            activePoolCached,
            zusdTokenCached,
            gasPoolAddress,
            ZUSD_GAS_COMPENSATION
        );

        // Send the collateral back to the user
        activePoolCached.sendETH(msg.sender, coll);
    }

    /**
     * Claim remaining collateral from a redemption or from a liquidation with ICR > MCR in Recovery Mode
     */
    function claimCollateral() external override {
        // send ETH from CollSurplus Pool to owner
        collSurplusPool.claimColl(msg.sender);
    }

    // --- Helper functions ---

    function _triggerBorrowingFee(
        ITroveManager _troveManager,
        IZUSDToken _zusdToken,
        uint256 _ZUSDAmount,
        uint256 _maxFeePercentage
    ) internal returns (uint256) {
        _troveManager.decayBaseRateFromBorrowing(); // decay the baseRate state variable
        uint256 ZUSDFee = _troveManager.getBorrowingFee(_ZUSDAmount);

        _requireUserAcceptsFee(ZUSDFee, _ZUSDAmount, _maxFeePercentage);
        _zusdToken.mint(address(feeDistributor), ZUSDFee);
        feeDistributor.distributeFees();

        return ZUSDFee;
    }

    function _getUSDValue(uint256 _coll, uint256 _price) internal pure returns (uint256) {
        uint256 usdValue = _price.mul(_coll).div(DECIMAL_PRECISION);

        return usdValue;
    }

    function _getCollChange(uint256 _collReceived, uint256 _requestedCollWithdrawal)
        internal
        pure
        returns (uint256 collChange, bool isCollIncrease)
    {
        if (_collReceived != 0) {
            collChange = _collReceived;
            isCollIncrease = true;
        } else {
            collChange = _requestedCollWithdrawal;
        }
    }

    /// Update trove's coll and debt based on whether they increase or decrease
    function _updateTroveFromAdjustment(
        ITroveManager _troveManager,
        address _borrower,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _debtChange,
        bool _isDebtIncrease
    ) internal returns (uint256, uint256) {
        uint256 newColl = (_isCollIncrease)
            ? _troveManager.increaseTroveColl(_borrower, _collChange)
            : _troveManager.decreaseTroveColl(_borrower, _collChange);
        uint256 newDebt = (_isDebtIncrease)
            ? _troveManager.increaseTroveDebt(_borrower, _debtChange)
            : _troveManager.decreaseTroveDebt(_borrower, _debtChange);

        return (newColl, newDebt);
    }

    function _moveTokensAndETHfromAdjustment(
        IActivePool _activePool,
        IZUSDToken _zusdToken,
        address _borrower,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _ZUSDChange,
        bool _isDebtIncrease,
        uint256 _netDebtChange,
        address _tokensRecipient
    ) internal {
        if (_isDebtIncrease) {
            _mintZusdAndIncreaseActivePoolDebt(
                _activePool,
                _zusdToken,
                _tokensRecipient,
                _ZUSDChange,
                _netDebtChange
            );
        } else {
            _burnZusdAndDecreaseActivePoolDebt(_activePool, _zusdToken, _borrower, _ZUSDChange);
        }

        if (_isCollIncrease) {
            _activePoolAddColl(_activePool, _collChange);
        } else {
            _activePool.sendETH(_borrower, _collChange);
        }
    }

    /// Send ETH to Active Pool and increase its recorded ETH balance
    function _activePoolAddColl(IActivePool _activePool, uint256 _amount) internal {
        (bool success, ) = address(_activePool).call{ value: _amount }("");
        require(success, "BorrowerOps: Sending ETH to ActivePool failed");
    }

    /// Issue the specified amount of ZUSD to _account and increases the total active debt (_netDebtIncrease potentially includes a ZUSDFee)
    function _mintZusdAndIncreaseActivePoolDebt(
        IActivePool _activePool,
        IZUSDToken _zusdToken,
        address _account,
        uint256 _ZUSDAmount,
        uint256 _netDebtIncrease
    ) internal {
        _activePool.increaseZUSDDebt(_netDebtIncrease);
        _zusdToken.mint(_account, _ZUSDAmount);
    }

    /// Burn the specified amount of ZUSD from _account and decreases the total active debt
    function _burnZusdAndDecreaseActivePoolDebt(
        IActivePool _activePool,
        IZUSDToken _zusdToken,
        address _account,
        uint256 _ZUSD
    ) internal {
        _activePool.decreaseZUSDDebt(_ZUSD);
        _zusdToken.burn(_account, _ZUSD);
    }

    // --- 'Require' wrapper functions ---

    function _requireSingularCollChange(uint256 _collWithdrawal) internal view {
        require(
            msg.value == 0 || _collWithdrawal == 0,
            "BorrowerOperations: Cannot withdraw and add coll"
        );
    }

    function _requireCallerIsBorrower(address _borrower) internal view {
        require(
            msg.sender == _borrower,
            "BorrowerOps: Caller must be the borrower for a withdrawal"
        );
    }

    function _requireNonZeroAdjustment(uint256 _collWithdrawal, uint256 _ZUSDChange)
        internal
        view
    {
        require(
            msg.value != 0 || _collWithdrawal != 0 || _ZUSDChange != 0,
            "BorrowerOps: There must be either a collateral change or a debt change"
        );
    }

    function _requireTroveisActive(ITroveManager _troveManager, address _borrower) internal view {
        uint256 status = _troveManager.getTroveStatus(_borrower);
        require(status == 1, "BorrowerOps: Trove does not exist or is closed");
    }

    function _requireTroveisNotActive(ITroveManager _troveManager, address _borrower)
        internal
        view
    {
        uint256 status = _troveManager.getTroveStatus(_borrower);
        require(status != 1, "BorrowerOps: Trove is active");
    }

    function _requireNonZeroDebtChange(uint256 _ZUSDChange) internal pure {
        require(_ZUSDChange > 0, "BorrowerOps: Debt increase requires non-zero debtChange");
    }

    function _requireNotInRecoveryMode(uint256 _price) internal view {
        require(
            !_checkRecoveryMode(_price),
            "BorrowerOps: Operation not permitted during Recovery Mode"
        );
    }

    function _requireNoCollWithdrawal(uint256 _collWithdrawal) internal pure {
        require(
            _collWithdrawal == 0,
            "BorrowerOps: Collateral withdrawal not permitted Recovery Mode"
        );
    }

    function _requireValidAdjustmentInCurrentMode(
        bool _isRecoveryMode,
        uint256 _collWithdrawal,
        bool _isDebtIncrease,
        LocalVariables_adjustTrove memory _vars
    ) internal view {
        /*
         *In Recovery Mode, only allow:
         *
         * - Pure collateral top-up
         * - Pure debt repayment
         * - Collateral top-up with debt repayment
         * - A debt increase combined with a collateral top-up which makes the ICR >= 150% and improves the ICR (and by extension improves the TCR).
         *
         * In Normal Mode, ensure:
         *
         * - The new ICR is above MCR
         * - The adjustment won't pull the TCR below CCR
         */
        if (_isRecoveryMode) {
            _requireNoCollWithdrawal(_collWithdrawal);
            if (_isDebtIncrease) {
                _requireICRisAboveCCR(_vars.newICR);
                _requireNewICRisAboveOldICR(_vars.newICR, _vars.oldICR);
            }
        } else {
            // if Normal Mode
            _requireICRisAboveMCR(_vars.newICR);
            _vars.newTCR = _getNewTCRFromTroveChange(
                _vars.collChange,
                _vars.isCollIncrease,
                _vars.netDebtChange,
                _isDebtIncrease,
                _vars.price
            );
            _requireNewTCRisAboveCCR(_vars.newTCR);
        }
    }

    function _requireICRisAboveMCR(uint256 _newICR) internal view {
        require(
            _newICR >= liquityBaseParams.MCR(),
            "BorrowerOps: An operation that would result in ICR < MCR is not permitted"
        );
    }

    function _requireICRisAboveCCR(uint256 _newICR) internal view {
        require(
            _newICR >= liquityBaseParams.CCR(),
            "BorrowerOps: Operation must leave trove with ICR >= CCR"
        );
    }

    function _requireNewICRisAboveOldICR(uint256 _newICR, uint256 _oldICR) internal pure {
        require(
            _newICR >= _oldICR,
            "BorrowerOps: Cannot decrease your Trove's ICR in Recovery Mode"
        );
    }

    function _requireNewTCRisAboveCCR(uint256 _newTCR) internal view {
        require(
            _newTCR >= liquityBaseParams.CCR(),
            "BorrowerOps: An operation that would result in TCR < CCR is not permitted"
        );
    }

    function _requireAtLeastMinNetDebt(uint256 _netDebt) internal pure {
        require(
            _netDebt >= MIN_NET_DEBT,
            "BorrowerOps: Trove's net debt must be greater than minimum"
        );
    }

    function _requireValidZUSDRepayment(uint256 _currentDebt, uint256 _debtRepayment)
        internal
        pure
    {
        require(
            _debtRepayment <= _currentDebt.sub(ZUSD_GAS_COMPENSATION),
            "BorrowerOps: Amount repaid must not be larger than the Trove's debt"
        );
    }

    function _requireCallerIsStabilityPool() internal view {
        require(msg.sender == stabilityPoolAddress, "BorrowerOps: Caller is not Stability Pool");
    }

    function _requireSufficientZUSDBalance(
        IZUSDToken _zusdToken,
        address _borrower,
        uint256 _debtRepayment
    ) internal view {
        require(
            _zusdToken.balanceOf(_borrower) >= _debtRepayment,
            "BorrowerOps: Caller doesnt have enough ZUSD to make repayment"
        );
    }

    function _requireValidMaxFeePercentage(uint256 _maxFeePercentage, bool _isRecoveryMode)
        internal
        view
    {
        if (_isRecoveryMode) {
            require(
                _maxFeePercentage <= DECIMAL_PRECISION,
                "Max fee percentage must less than or equal to 100%"
            );
        } else {
            require(
                _maxFeePercentage >= liquityBaseParams.BORROWING_FEE_FLOOR() &&
                    _maxFeePercentage <= DECIMAL_PRECISION,
                "Max fee percentage must be between 0.5% and 100%"
            );
        }
    }

    // --- ICR and TCR getters ---

    /// Compute the new collateral ratio, considering the change in coll and debt. Assumes 0 pending rewards.
    function _getNewNominalICRFromTroveChange(
        uint256 _coll,
        uint256 _debt,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _debtChange,
        bool _isDebtIncrease
    ) internal pure returns (uint256) {
        (uint256 newColl, uint256 newDebt) = _getNewTroveAmounts(
            _coll,
            _debt,
            _collChange,
            _isCollIncrease,
            _debtChange,
            _isDebtIncrease
        );

        uint256 newNICR = LiquityMath._computeNominalCR(newColl, newDebt);
        return newNICR;
    }

    /// Compute the new collateral ratio, considering the change in coll and debt. Assumes 0 pending rewards.
    function _getNewICRFromTroveChange(
        uint256 _coll,
        uint256 _debt,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _debtChange,
        bool _isDebtIncrease,
        uint256 _price
    ) internal pure returns (uint256) {
        (uint256 newColl, uint256 newDebt) = _getNewTroveAmounts(
            _coll,
            _debt,
            _collChange,
            _isCollIncrease,
            _debtChange,
            _isDebtIncrease
        );

        uint256 newICR = LiquityMath._computeCR(newColl, newDebt, _price);
        return newICR;
    }

    function _getNewTroveAmounts(
        uint256 _coll,
        uint256 _debt,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _debtChange,
        bool _isDebtIncrease
    ) internal pure returns (uint256, uint256) {
        uint256 newColl = _coll;
        uint256 newDebt = _debt;

        newColl = _isCollIncrease ? _coll.add(_collChange) : _coll.sub(_collChange);
        newDebt = _isDebtIncrease ? _debt.add(_debtChange) : _debt.sub(_debtChange);

        return (newColl, newDebt);
    }

    function _getNewTCRFromTroveChange(
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _debtChange,
        bool _isDebtIncrease,
        uint256 _price
    ) internal view returns (uint256) {
        uint256 totalColl = getEntireSystemColl();
        uint256 totalDebt = getEntireSystemDebt();

        totalColl = _isCollIncrease ? totalColl.add(_collChange) : totalColl.sub(_collChange);
        totalDebt = _isDebtIncrease ? totalDebt.add(_debtChange) : totalDebt.sub(_debtChange);

        uint256 newTCR = LiquityMath._computeCR(totalColl, totalDebt, _price);
        return newTCR;
    }

    function getCompositeDebt(uint256 _debt) external view override returns (uint256) {
        return _getCompositeDebt(_debt);
    }

    function BORROWING_FEE_FLOOR() external view override returns (uint256) {
        return liquityBaseParams.BORROWING_FEE_FLOOR();
    }

    function getMassetManager() external view override returns (IMassetManager) {
        return massetManager;
    }
}