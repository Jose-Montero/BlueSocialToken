// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

    /* Da Rules
    * TODO Before deployment of contract to Mainnet
    *
    * 1. Confirm MINIMUM_PARTICIPATION_AMOUNT and MAXIMUM_PARTICIPATION_AMOUNT below
    * 2. Adjust PRESALE_MINIMUM_FUNDING and PRESALE_MAXIMUM_FUNDING to desired EUR equivalents
    * 3. Adjust PRESALE_START_DATE and confirm the presale period
    * 4. Update TOTAL_PREALLOCATION to the total preallocations received
    * 5. Add each preallocation address and funding amount from the Sikoba bookmaker to the constructor function
    * 6. Test the deployment to a dev blockchain or Testnet to confirm the constructor will not run out of gas as this will vary with the number of preallocation account entries
    * 7. A stable version of Solidity has been used. Check for any major bugs in the Solidity release announcements after this version.
    * 8. Remember to send the preallocated funds when deploying the contract!
    *
    */

contract Owned {
    address public owner;

    function Owned() { owner = msg.sender; }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
}

contract BlueSocialPresale is Owned {

    // contract closed
    bool private saleHasEnded = false;

    // set whitelisting filter on/off
    bool private isWhitelistingActive = true;

    // Keep track of the total funding amount
    uint256 public totalFunding;

    // Minimum and maximum amounts per transaction for public participants
    uint256 public constant MINIMUM_PARTICIPATION_AMOUNT =   0.01 ether;
    uint256 public MAXIMUM_PARTICIPATION_AMOUNT = 5 ether;

    // Minimum and maximum goals of the presale
    uint256 public constant PRESALE_MINIMUM_FUNDING =  100 ether;
    uint256 public constant PRESALE_MAXIMUM_FUNDING = 705 ether;

    // Total preallocation in wei
    uint256 public constant TOTAL_PREALLOCATION = 15 ether;

    // Public presale period
    // Select UNIX TimeStamp for Date and time
    uint256 public constant PRESALE_START_DATE = 1511186400;
    uint256 public constant PRESALE_END_DATE = PRESALE_START_DATE + 2 weeks;

    // Owner can clawback after a date in the future, so no ethers remain trapped in the contract. This will only be relevant if the minimum funding level is not reached
    // Select UNIX TimeStamp for Date and time
    uint256 public constant OWNER_CLAWBACK_DATE = 1512306000;

    /// @notice Keep track of all participants contributions, including both the preallocation and public phases
    mapping (address => uint256) public balanceOf;

    /// List of whitelisted participants
    mapping (address => bool) public earlyParticipantWhitelist;

    /// @notice Log an event for each funding contributed during the public phase
    /// @notice Events are not logged when the constructor is being executed during deployment, so the preallocations will not be logged
    event LogParticipation(address indexed sender, uint256 value, uint256 timestamp);
    
    function BlueSocialPresale () payable {
    }

    /// @notice A participant sends a contribution to the contract's address between the PRESALE_STATE_DATE and the PRESALE_END_DATE
    /// @notice Only contributions between the MINIMUM_PARTICIPATION_AMOUNT and MAXIMUM_PARTICIPATION_AMOUNT are accepted. Otherwise the transaction is rejected and contributed amount is returned to the participant's account
    /// @notice A participant's contribution will be rejected if the presale has been funded to the maximum amount
    function () payable {
        require(!saleHasEnded);
        // A participant cannot send funds before the presale start date
        require(now > PRESALE_START_DATE);
        // A participant cannot send funds after the presale end date
        require(now < PRESALE_END_DATE);
        // A participant cannot send less than the minimum amount
        require(msg.value >= MINIMUM_PARTICIPATION_AMOUNT);
        // A participant cannot send more than the maximum amount
        require(msg.value <= MAXIMUM_PARTICIPATION_AMOUNT);
        // If whitelist filtering is active, if so then check the contributor is in list of addresses
        if (isWhitelistingActive) {
            require(earlyParticipantWhitelist[msg.sender]);
            require(safeAdd(balanceOf[msg.sender], msg.value) <= MAXIMUM_PARTICIPATION_AMOUNT);
        }
        // A participant cannot send funds if the presale has been reached the maximum funding amount
        require(safeAdd(totalFunding, msg.value) <= PRESALE_MAXIMUM_FUNDING);
        // Register the participant's contribution
        addBalance(msg.sender, msg.value);    
    }
    
    /// @notice The owner can withdraw ethers after the presale has completed, only if the minimum funding level has been reached
    function ownerWithdraw(uint256 value) external onlyOwner {
        if (totalFunding >= PRESALE_MAXIMUM_FUNDING) {
            owner.transfer(value);
            saleHasEnded = true;
        } else {
        // The owner cannot withdraw before the presale ends
        require(now >= PRESALE_END_DATE);
        // The owner cannot withdraw if the presale did not reach the minimum funding amount
        require(totalFunding >= PRESALE_MINIMUM_FUNDING);
        // Withdraw the amount requested
        owner.transfer(value);
        }
    }

    /// @notice The participant will need to withdraw their funds from this contract if the presale has not achieved the minimum funding level
    function participantWithdrawIfMinimumFundingNotReached(uint256 value) external {
        // Participant cannot withdraw before the presale ends
        require(now >= PRESALE_END_DATE);
        // Participant cannot withdraw if the minimum funding amount has been reached
        require(totalFunding <= PRESALE_MINIMUM_FUNDING);
        // Participant can only withdraw an amount up to their contributed balance
        assert(balanceOf[msg.sender] >= value);
        // Participant's balance is reduced by the claimed amount.
        balanceOf[msg.sender] = safeSub(balanceOf[msg.sender], value);
        // Send ethers back to the participant's account
        msg.sender.transfer(value);
    }

    /// @notice The owner can clawback any ethers after a date in the future, so no ethers remain trapped in this contract. This will only be relevant if the minimum funding level is not reached
    function ownerClawback() external onlyOwner {
        // The owner cannot withdraw before the clawback date
        require(now >= OWNER_CLAWBACK_DATE);
        // Send remaining funds back to the owner
        owner.transfer(this.balance);
    }

    // Set addresses in whitelist
    function setEarlyParicipantWhitelist(address addr, bool status) external onlyOwner {
        earlyParticipantWhitelist[addr] = status;
    }

    /// Ability to turn of whitelist filtering after 24 hours
    function whitelistFilteringSwitch() external onlyOwner {
        if (isWhitelistingActive) {
            isWhitelistingActive = false;
            MAXIMUM_PARTICIPATION_AMOUNT = 30000 ether;
        } else {
            revert();
        }
    }

    /// @dev Keep track of participants contributions and the total funding amount
    function addBalance(address participant, uint256 value) private {
        // Participant's balance is increased by the sent amount
        balanceOf[participant] = safeAdd(balanceOf[participant], value);
        // Keep track of the total funding amount
        totalFunding = safeAdd(totalFunding, value);
        // Log an event of the participant's contribution
        LogParticipation(participant, value, now);
    }

    /// @dev Throw an exception if the amounts are not equal
    function assertEquals(uint256 expectedValue, uint256 actualValue) private constant {
        assert(expectedValue == actualValue);
    }

    function safeMul(uint a, uint b) internal returns (uint) {
        uint c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function safeSub(uint a, uint b) internal returns (uint) {
        assert(b <= a);
        return a - b;
    }

    function safeAdd(uint a, uint b) internal returns (uint) {
        uint c = a + b;
        assert(c>=a && c>=b);
        return c;
    }
}


pragma solidity ^0.8.9;

import "./ERC223.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";

contract BlueSocialPresale is ContractReceiver {
  using SafeMath for uint256;

  bool    public active = false;
  address public tokenAddress;
  uint256 public hardCap;
  uint256 public sold;

  struct Order {
    address owner;
    uint256 amount;
    uint256 lockup;
    bool    claimed;
  }

  mapping(uint256 => Order) private orders;
  uint256 private latestOrderId = 0;
  address private owner;
  address private treasury;

  event Activated(uint256 time);
  event Finished(uint256 time);
  event Purchase(address indexed purchaser, uint256 id, uint256 amount, uint256 purchasedAt, uint256 redeemAt);
  event Claim(address indexed purchaser, uint256 id, uint256 amount);

  function BlueSocialPresale(address token, address ethRecepient, uint256 presaleHardCap) public {
    tokenAddress  = token;
    owner         = msg.sender;
    treasury      = ethRecepient;
    hardCap       = presaleHardCap;
  }

  function tokenFallback(address /* _from */, uint _value, bytes /* _data */) public {
    // Accept only BlueSocial ERC223 token
    if (msg.sender != tokenAddress) { revert(); }
    // If the Presale is active do not accept incoming transactions
    if (active) { revert(); }
    // Only accept one transaction of the right amount
    if (_value != hardCap) { revert(); }

    active = true;
    Activated(now);
  }

  function amountOf(uint256 orderId) constant public returns (uint256 amount) {
    return orders[orderId].amount;
  }

  function lockupOf(uint256 orderId) constant public returns (uint256 timestamp) {
    return orders[orderId].lockup;
  }

  function ownerOf(uint256 orderId) constant public returns (address orderOwner) {
    return orders[orderId].owner;
  }

  function isClaimed(uint256 orderId) constant public returns (bool claimed) {
    return orders[orderId].claimed;
  }

  function () external payable {
    revert();
  }

  function shortBuy() public payable {
    // 10% bonus
    uint256 lockup = now + 12 weeks;
    uint256 priceDiv = 1818181818;
    processPurchase(priceDiv, lockup);
  }

  function mediumBuy() public payable {
    // 25% bonus
    uint256 lockup = now + 24 weeks;
    uint256 priceDiv = 1600000000;
    processPurchase(priceDiv, lockup);
  }

  function longBuy() public payable {
    // 50% bonus
    uint256 lockup = now + 52 weeks;
    uint256 priceDiv = 1333333333;
    processPurchase(priceDiv, lockup);
  }

  function processPurchase(uint256 priceDiv, uint256 lockup) private {
    if (!active) { revert(); }
    if (msg.value == 0) { revert(); }
    ++latestOrderId;

    uint256 purchasedAmount = msg.value.div(priceDiv);
    if (purchasedAmount == 0) { revert(); } // not enough ETH sent
    if (purchasedAmount > hardCap - sold) { revert(); } // too much ETH sent

    orders[latestOrderId] = Order(msg.sender, purchasedAmount, lockup, false);
    sold += purchasedAmount;

    treasury.transfer(msg.value);
    Purchase(msg.sender, latestOrderId, purchasedAmount, now, lockup);
  }

  function redeem(uint256 orderId) public {
    if (orderId > latestOrderId) { revert(); }
    Order storage order = orders[orderId];

    // only owner can withdraw
    if (msg.sender != order.owner) { revert(); }
    if (now < order.lockup) { revert(); }
    if (order.claimed) { revert(); }
    order.claimed = true;

    ERC223 token = ERC223(tokenAddress);
    token.transfer(order.owner, order.amount);

    Claim(order.owner, orderId, order.amount);
  }

  function endPresale() public {
    // only the creator of the smart contract
    // can end the crowdsale prematurely
    if (msg.sender != owner) { revert(); }
    // can only stop an active crowdsale
    if (!active) { revert(); }
    _end();
  }

  function _end() private {
    // if there are any tokens remaining - return them to the owner
    if (sold < hardCap) {
      ERC223 token = ERC223(tokenAddress);
      token.transfer(treasury, hardCap.sub(sold));
    }
    active = false;
    Finished(now);
  }
}