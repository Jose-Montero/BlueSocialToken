// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IEIP4931.sol";

contract BlueSocialUpgrade is  IEIP4931 {
	using SafeERC20  for IERC20;

	uint256 constant RATIO_SCALE = 10**18;
    
	IERC20 private Source;
	IERC20 private destination;
	bool private upgradeStatus;
	bool private downgradeStatus;
	uint256 private numeratorRatio;
	uint256 private denominatorRatio;
	uint256 private BlueSocialUpgradedTotal;

	mapping(address => uint256) public upgradedBalance;

	constructor(address _Source, address _destination, bool _upgradeStatus, bool _downgradeStatus, uint256 _numeratorRatio, uint256 _denominatorRatio) {
		require(_Source != _destination, "BlueSocialUpgrade: BST and destination addresses are the same");
		require(_Source != address(0), "BlueSocialUpgrade: BST address cannot be zero address");
		require(_destination != address(0), "BlueSocialUpgrade: destination address cannot be zero address");
		require(_numeratorRatio > 0, "BlueSocialUpgrade: numerator of ratio cannot be zero");
		require(_denominatorRatio > 0, "BlueSocialUpgrade: denominator of ratio cannot be zero");

		Source = IERC20(_Source);
		destination = IERC20(_destination);
		upgradeStatus = _upgradeStatus;
		downgradeStatus = _downgradeStatus;
		numeratorRatio = _numeratorRatio;
		denominatorRatio = _denominatorRatio;
	}

	function upgradeSource() external view returns(address) {
		return address(Source);
	}

	function upgradeDestination() external view returns(address) {
		return address(destination);
	}

	function isUpgradeActive() external view returns(bool) {
		return upgradeStatus;
	}

	function isDowngradeActive() external view returns(bool) {
		return downgradeStatus;
	}

	function ratio() external view returns(uint256, uint256) {
		return (numeratorRatio, denominatorRatio);
	}

	function totalUpgraded() external view returns(uint256) {
		return BlueSocialUpgradedTotal;
	}

	function computeUpgrade(uint256 SourceAmount)
		public
		view
		returns (uint256 destinationAmount, uint256 SourceRemainder)
	{
		SourceRemainder = SourceAmount % (numeratorRatio / denominatorRatio);
		uint256 upgradeableAmount = SourceAmount - (SourceRemainder * RATIO_SCALE);
		destinationAmount = upgradeableAmount * (numeratorRatio / denominatorRatio);
	}

	function computeDowngrade(uint256 destinationAmount)
		public
		view
		returns (uint256 SourceAmount, uint256 destinationRemainder)
	{
		destinationRemainder = destinationAmount % (denominatorRatio / numeratorRatio);
		uint256 upgradeableAmount = destinationAmount - (destinationRemainder * RATIO_SCALE);
		SourceAmount = upgradeableAmount / (denominatorRatio / numeratorRatio);
	}

	function upgrade(address _to, uint256 SourceAmount) external {
		require(upgradeStatus == true, "BlueSocialUpgrade: upgrade status is not active");
		(uint256 destinationAmount, uint256 SourceRemainder) = computeUpgrade(SourceAmount);
		SourceAmount -= SourceRemainder;
		require(SourceAmount > 0, "BlueSocialUpgrade: disallow conversions of zero value");

		upgradedBalance[msg.sender] += SourceAmount;
		Source.safeTransferFrom(
			msg.sender,
			address(this),
			SourceAmount
			);
		destination.safeTransfer(_to, destinationAmount);
		BlueSocialUpgradedTotal += SourceAmount;
		emit Upgrade(msg.sender, _to, SourceAmount, destinationAmount);
	}

	function downgrade(address _to, uint256 destinationAmount) external {
		require(upgradeStatus == true, "BlueSocialUpgrade: upgrade status is not active");
		(uint256 SourceAmount, uint256 destinationRemainder) = computeDowngrade(destinationAmount);
		destinationAmount -= destinationRemainder;
		require(destinationAmount > 0, "BlueSocialUpgrade: disallow conversions of zero value");
		require(upgradedBalance[msg.sender] >= SourceAmount,
			"BlueSocialUpgrade: can not downgrade more than previously upgraded"
			);

		upgradedBalance[msg.sender] -= SourceAmount;
		destination.safeTransferFrom(
			msg.sender,
			address(this),
			destinationAmount
			);
		Source.safeTransfer(_to, SourceAmount);
		BlueSocialUpgradedTotal -= SourceAmount;
		emit Downgrade(msg.sender, _to, SourceAmount, destinationAmount);
	}
}
