// SPDX-License-Identifier: KuhnSoft
pragma solidity >=0.5.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract YourToken is ERC20, Ownable {

    uint256 public constant MAX_SUPPLY = 1000000000; // 1 billion
    uint256 public constant WHITELIST_SALE_AMOUNT = 50000000; // 50 million
    uint256 public constant DAY1_TO_DAY5_SALE_AMOUNT = 20000000; // 20 million per day
    uint256 public constant DAILY_SALE_AMOUNT_AFTER_DAY7 = 1000000; // 1 million per day
    uint256 public saleStartTimestamp;
    uint256 public day6Timestamp;
    uint256 public day7Timestamp;
    uint256 public day350Timestamp;
    mapping(address => bool) public whitelist;
    uint256 public whitelistSalePrice;
    uint256 public day1ToDay5SalePrice;
    uint256 public afterDay7SalePrice;

    constructor(
        uint256 _saleStartTimestamp,
        uint256 _whitelistSalePrice,
        uint256 _day1ToDay5SalePrice
    ) ERC20("YourToken", "YRT") {
        require(_saleStartTimestamp > block.timestamp, "Sale start timestamp must be in the future");
        saleStartTimestamp = _saleStartTimestamp;
        day6Timestamp = _saleStartTimestamp + 5 days;
        day7Timestamp = _saleStartTimestamp + 6 days;
        day350Timestamp = _saleStartTimestamp + 349 days;
        whitelistSalePrice = _whitelistSalePrice;
        day1ToDay5SalePrice = _day1ToDay5SalePrice;
        _mint(address(this), MAX_SUPPLY);
    }

    function addToWhitelist(address _address) external onlyOwner {
        whitelist[_address] = true;
    }

    function buyTokens() external payable {
        require(block.timestamp >= saleStartTimestamp, "Sale has not started yet");
        require(block.timestamp < day350Timestamp, "Sale has ended");
        uint256 tokensToBuy;

        if (block.timestamp < day6Timestamp) {
            require(msg.value == whitelistSalePrice, "Incorrect value sent");
            tokensToBuy = WHITELIST_SALE_AMOUNT;
        } else if (block.timestamp < day7Timestamp) {
            revert("Sale is paused");
        } else {
            require(msg.value == afterDay7SalePrice, "Incorrect value sent");
            tokensToBuy = DAILY_SALE_AMOUNT_AFTER_DAY7;
        }

        _transfer(address(this), msg.sender, tokensToBuy);
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}

