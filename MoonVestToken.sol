// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.0/contracts/token/ERC20/ERC20.sol";

contract MoonVestToken is ERC20 {

    /// @notice Divisor for fraction of transferred funds that will be burned
    uint64 private baseBurnDivisor = 0;

	/// @notice Divisor for fraction of transferred funds that will be collected as fee
    uint64 private feeDivisor = 16;

	/// @notice Used to calculate burn rate for large transfers
    uint64 private whaleBurnMultiplier = 12;

	/// @notice Count of all transfers
    uint64 private totalTransfers = 0;

	/// @dev Address that collects fees
    address private feeAddress;

	/// @dev Admin address
    address private admin;

    /// @notice Whether free transfers should be allowed
    bool public allowFreeTransfer = true;

    constructor() ERC20("MoonVest.Network", "MVN") {  
		_setupDecimals(9);
		_mint(msg.sender, 1e24);
		admin = msg.sender;
		feeAddress = msg.sender;
    }

	/**
    * @dev Throws if called by any account other than the admin
    */
    modifier onlyAdmin() {
        require(msg.sender == admin, "MoonVestToken: caller is not Admin");
        _;
    }

    /**
     * @notice Set the burn divisor used to determine burn rate
     * @param _burnDivisor int used as divisor to calculate burn rate. total / divisor = burn_rate
     */
    function setBaseBurnDivisor(uint256 _baseBurnDivisor) external onlyAdmin {
        require( _baseBurnDivisor > 9, "MoonVestToken::setBurnDivisor: burnDivisor must be greater than 9"); // 100 / 10 = 10% max base burn
        baseBurnDivisor = _baseBurnDivisor;
    }

	/**
     * @notice Set the burn divisor used to determine burn rate
     * @param _burnDivisor int used as divisor to calculate burn rate. total / divisor = burn_rate
     */
    function setFeeDivisor(uint256 _feeDivisor) external onlyAdmin {
        require( _feeDivisor > 9, "MoonVestToken::setFeeDivisor: feeDivisor must be greater than 9"); // 100 / 10 == 10% Max Fee
        feeDivisor = _feeDivisor;
    }

	/**
     * @notice Set the burn divisor used to determine burn rate
     * @param _burnDivisor int used as divisor to calculate burn rate. total / divisor = burn_rate
     */
    function setWhaleBurnMultiplier(uint256 _whaleBurnMultiplier) external onlyAdmin {
        require( _feeDivisor < 25, "MoonVestToken::setFeeDivisor: _whaleBurnMultiplier must be less than 25"); 
        whaleBurnMultiplier = _whaleBurnMultiplier;
    }

    /**
     * @notice Transfer and burn
     * @param recipient Address to recieve transferred tokens
     * @param amount Amount to be sent. A portion of this will be burned.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {		
		uint256 burnAmount = ( amount / baseBurnDivisor ) + ( ( amount**2 / totalSupply() ) * whaleBurnMultiplier ) + ( amount * 100 / totalTransfers );
		if ( burnAmount > amount / 7 ) {
			burnAmount = amount / 7;
		}
		uint256 feeAmount = amount / feeDivisor;
		totalTransfers++;
		_burn(msg.sender, burnAmount);
		super.transfer(feeAddress, feeAmount);
        return super.transfer(recipient, amount - burnAmount - feeAmount);
    }

    /**
     * @notice Transfer and burn from approved allocation.
     * @param sender address sending tokens.
     * @param recipient address to recieve transferred tokens.
     * @param amount Amount to be sent. A portion of this will be burned.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        uint256 burnAmount = amount / burnDivisor;
        _burn(sender, burnAmount);
        return super.transferFrom(sender, recipient, amount - burnAmount);
    }

    /**
     * @notice Transfer without burn. This is not the standard ERC20 transfer.
     * @param recipient address to recieve transferred tokens.
     * @param amount Amount to be sent.
     */
    function freeTransfer(address recipient, uint256 amount) external returns (bool) {
        require(allowFreeTransfer, "MoonVestToken::freeTransfer: freeTransfer is currently turned off");
        return super.transfer( recipient, amount );
    }

    /**
     * @notice Transfer without burn from approved allocation. This is not the standard ERC20 transferFrom.
     * @param sender address sending tokens.
     * @param recipient address to recieve transferred tokens.
     * @param amount Amount to be sent.
     */
    function freeTransferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        require(allowFreeTransfer, "MoonVestToken::freeTransferFrom: freeTrasnfer is currently turned off");
        return super.transferFrom( sender, recipient, amount );
    }

    /**
     * @param _allowFreeTransfer Whether free transfers should be allowed
     */
    function setAllowFreeTransfer(bool _allowFreeTransfer) external onlyAdmin {
        allowFreeTransfer = _allowFreeTransfer;
    }

	/**
	* @param _newAdmin address to become new Admin.
	*/
    function setAdmin(address _newAdmin) external onlyAdmin {
        admin = _newAdmin;
    }

    /**
     * @notice Burns (destroys) tokens and reduces total supply.
     * @param amount Amount of tokens to burn.
     */
    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    /**
     * @notice Transfers tokens to multiple addresses.
     * @param addresses Addresses to send tokens to.
     * @param amounts Amounts of tokens to send.
     */
    function multiTransfer(address[] calldata addresses, uint256[] calldata amounts) external {
        require(addresses.length == amounts.length, "MoonVestToken::multiTransfer: addresses and amounts count do not match");

        for (uint i = 0; i < amounts.length; i++) {
            super.transfer(addresses[i], amounts[i]);
        }
    }

}