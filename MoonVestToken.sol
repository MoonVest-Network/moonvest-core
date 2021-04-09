// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the BEP20 standard
 */
interface BEP20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom( address sender, address recipient, uint256 amount ) external returns (bool);
    event Transfer( address indexed from, address indexed to, uint256 value );
    event Approval( address indexed owner, address indexed spender, uint256 value );
}

contract MoonVestToken is BEP20 {
    /// @dev Token Details
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply = 1e24;
    string private constant _name = "MoonVest.Network";
    string private constant _symbol = "MVN";
    uint8 private constant _decimals = 9;

    /// @dev Divisors/Multiplier used to calculate burn and fees
    uint8 private baseBurnDivisor = 0;
    uint8 private feeDivisor = 16;
    uint8 private whaleBurnMultiplier = 20;

    /// @dev Admin and address where fees are sent
    address private admin;
    address private feeAddress;

    mapping(address => bool) private excludedSenders;
    mapping(address => bool) private excludedReceivers;

    /// @dev freeTransfer() enabled
    bool private allowFreeTransfer = true;

    constructor() {
        admin = msg.sender;
        feeAddress = msg.sender;
		_balances[msg.sender] = _totalSupply;
    }

    /**
     * @dev Throws if called by any account other than the admin
     */
    modifier onlyAdmin() {
        require(msg.sender == admin, "MoonVestToken: caller is not Admin");
        _;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function name() external pure returns (string memory) {
        return _name;
    }

    function symbol() external pure returns (string memory) {
        return _symbol;
    }

    function decimals() external pure returns (uint8) {
        return _decimals;
    }

    /**
     * @return Balance of given @param account
     */
    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @return Allowance given to @param spender by @param owner
     */
    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @notice Approves @param spender to spend up to @param amount on behalf of caller
     */
    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Increases the spending allowance granted to @param spender for caller by @param addedValue
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender] + addedValue
        );
        return true;
    }

    /**
     * @notice Decreases the spending allowance granted to @param spender for caller by @param subtractedValue
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    /**
     * @param _baseBurnDivisor divisor to calculate base burn rate. amount / divisor = baseBurnRate
     */
    function setBaseBurnDivisor(uint8 _baseBurnDivisor) external onlyAdmin {
        require( _baseBurnDivisor > 7, "MoonVestToken::setBaseBurnDivisor: burnDivisor must be greater than 7" ); // 100 / 8 = 12.5% max base burn
        baseBurnDivisor = _baseBurnDivisor;
    }

    /**
     * @param _feeDivisor divisor to calculate total fees (not burned). amount / divisor = fees
     */
    function setFeeDivisor(uint8 _feeDivisor) external onlyAdmin {
        require( _feeDivisor > 9, "MoonVestToken::setFeeDivisor: feeDivisor must be greater than 9" ); // 100 / 10 = 10% Max Fee
        feeDivisor = _feeDivisor;
    }

    /**
     * @param _whaleBurnMultiplier Multiplier to calculate amount burned for large transfers
     */
    function setWhaleBurnMultiplier(uint8 _whaleBurnMultiplier) external onlyAdmin {
        require( _whaleBurnMultiplier < 25, "MoonVestToken::setWhaleBurnMultiplier: _whaleBurnMultiplier must be less than 25" );
        whaleBurnMultiplier = _whaleBurnMultiplier;
    }

    /**
     * @param _feeAddress address to collect fees
     */
    function setFeeAddress(address _feeAddress) external onlyAdmin {
        feeAddress = _feeAddress;
    }

    /**
     * @param _senderToAdd address to exclude from paying fees when sending
     */
    function addExcludedSender(address _senderToAdd) external onlyAdmin {
        excludedSenders[_senderToAdd] = true;
    }

    /**
     * @param _senderToRemove address to remove from fee exception when sending
     */
    function removeExcludedSender(address _senderToRemove) external onlyAdmin {
        excludedSenders[_senderToRemove] = false;
    }

    /**
     * @param _receiverToAdd address to exclude from paying fees when receiving
     */
    function addExcludedReceiver(address _receiverToAdd) external onlyAdmin {
        excludedReceivers[_receiverToAdd] = true;
    }

    /**
     * @param _receiverToRemove address to remove from fee exception when receiving
     */
    function removeExcludedReceiver(address _receiverToRemove) external onlyAdmin {
        excludedReceivers[_receiverToRemove] = false;
    }

	/**
     * @return bool wether @param sender is excluded from fees
     */
    function isExcludedSender(address sender) external view returns(bool) {
        return excludedSenders[sender];
    }

    /**
     * @return bool wether @param receiver is excluded from fees
     */
    function isExcludedReceiver(address receiver) external view returns(bool) {
        return excludedReceivers[receiver];
    }

    /**
     * @param _allowFreeTransfer Whether free transfers should be allowed to public
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
     * @notice Transfer, burn, and collect fee
     * @param recipient Address to recieve transferred tokens
     * @param amount Amount to be sent. A portion of this will be burned and collected as fees
     */
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        // Bypass fees if sender or reciever is excluded
        if (excludedSenders[msg.sender] || excludedReceivers[recipient]) {
            _transfer(msg.sender, recipient, amount);
            return true;
        }
		
		// Calculate burn and fee amount
        uint256 burnAmount = (amount / baseBurnDivisor) + ((amount**2 / _totalSupply) * whaleBurnMultiplier);
        if (burnAmount > amount / 8) {
            burnAmount = amount / 8;
        }
        uint256 feeAmount = amount / feeDivisor;
        
		// Burn/transfer tokens
		_burn(msg.sender, burnAmount);
        _transfer(msg.sender, feeAddress, feeAmount);
        _transfer(msg.sender, recipient, amount - burnAmount - feeAmount);
        return true;
    }

    /**
     * @notice Transfer, burn, and collect fee from approved allowance.
     * @param sender address sending tokens.
     * @param recipient address to recieve transferred tokens.
     * @param amount Amount to be sent. A portion of this will be burned.
     */
    function transferFrom( address sender, address recipient, uint256 amount ) external override returns (bool) {
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require( currentAllowance >= amount, "BEP20: transfer amount exceeds allowance" );
        _approve(sender, msg.sender, currentAllowance - amount);

        // Bypass fees if sender or reciever is excluded
        if (excludedSenders[msg.sender] || excludedReceivers[recipient]) {
            _transfer(sender, recipient, amount);
            return true;
        }

		// Calculate burn and fee amount
        uint256 burnAmount = (amount / baseBurnDivisor) + ((amount**2 / _totalSupply) * whaleBurnMultiplier);
        if (burnAmount > amount / 8) {
            burnAmount = amount / 8;
        }
        uint256 feeAmount = amount / feeDivisor;
        
		// Burn/transfer tokens
		_burn(sender, burnAmount);
        _transfer(sender, feeAddress, feeAmount);
        _transfer(sender, recipient, amount - burnAmount - feeAmount);
        return true;
    }

    /**
     * @notice Transfer without burn. This is not the standard BEP20 transfer.
     * @param recipient address to recieve transferred tokens.
     * @param amount Amount to be sent.
     */
    function freeTransfer(address recipient, uint256 amount) external {
        require( allowFreeTransfer, "MoonVestToken::freeTransfer: freeTransfer is currently turned off" );
        _transfer(msg.sender, recipient, amount);
    }

    /**
     * @notice Transfer without burn from approved allowance. This is not the standard ERC20 transferFrom.
     * @param sender address sending tokens.
     * @param recipient address to recieve transferred tokens.
     * @param amount Amount to be sent.
     */
    function freeTransferFrom(address sender, address recipient, uint256 amount ) external {
        require( allowFreeTransfer, "MoonVestToken::freeTransferFrom: freeTrasnfer is currently turned off" );
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require( currentAllowance >= amount, "BEP20: transfer amount exceeds allowance" );
        _approve(sender, msg.sender, currentAllowance - amount);
        _transfer(sender, recipient, amount);
    }

    /**
     * @notice Transfers tokens to multiple addresses.
     * @param addresses Addresses to send tokens to.
     * @param amounts Amounts of tokens to send.
     */
    function multiTransfer( address[] calldata addresses, uint256[] calldata amounts ) external {
		require( allowFreeTransfer, "MoonVestToken::freeTransferFrom: freeTrasnfer is currently turned off" );
        require( addresses.length == amounts.length, "MoonVestToken::multiTransfer: addresses and amounts count do not match" );
        for (uint256 i = 0; i < amounts.length; i++) {
            _transfer(msg.sender, addresses[i], amounts[i]);
        }
    }

    /**
     * @notice Destroys @param amount tokens and reduces total supply.
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Approves spending to @param spender of up to @param amount tokens from @param owner
     */
    function _approve( address owner, address spender, uint256 amount ) private {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Moves @param amount tokens from @param sender to @param recipient
     */
    function _transfer(address sender, address recipient, uint256 amount) private {
        require(recipient != address(0), "BEP20: transfer to the zero address");
        uint256 senderBalance = _balances[sender];
        require( senderBalance >= amount, "BEP20: transfer amount exceeds balance" );
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

    /**
     * @notice Destroys @param amount tokens from @param account and reduces total supply
     */
    function _burn(address account, uint256 amount) private {
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "BEP20: burn amount exceeds balance");
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }
}
