

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EscrowMarketplace {
    struct Listing {
        address sellerAddr;
        uint256 priceAmt;
        address buyerAddr;
        bool isSoldStatus;
        bool isDeliveredStatus;
    }

    mapping(string => Listing) public listings;
    mapping(address => uint256) public escrowFunds;
    address public admin;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Admin Only");
        _;
    }

    modifier onlyBuyer(string memory _item) {
        require(listings[_item].buyerAddr == msg.sender, "Buyer Only");
        _;
    }

    modifier onlySeller(string memory _item) {
        require(listings[_item].sellerAddr == msg.sender, "Seller Only");
        _;
    }

    event ItemListed(string itemName, address indexed seller, uint256 price);
    event ItemPurchased(string itemName, address indexed buyer);
    event ItemConfirmed(string itemName, address indexed buyer);
    event DisputeSettled(string itemName, address indexed resolver, bool isBuyerRight);

    constructor() {
        admin = msg.sender;
    }

    function addListing(string memory _item, uint256 _price) public {
        require(listings[_item].sellerAddr == address(0), "Item already listed");

        listings[_item] = Listing({
            sellerAddr: msg.sender,
            priceAmt: _price,
            buyerAddr: address(0),
            isSoldStatus: false,
            isDeliveredStatus: false
        });

        emit ItemListed(_item, msg.sender, _price);
    }

    function purchaseItem(string memory _item) public payable {
        Listing storage listing = listings[_item];
        require(listing.sellerAddr != address(0), "Item not listed");
        require(!listing.isSoldStatus, "Item already sold");
        require(msg.value == listing.priceAmt, "Incorrect price");

        listing.buyerAddr = msg.sender;
        listing.isSoldStatus = true;
        escrowFunds[address(this)] += msg.value;

        emit ItemPurchased(_item, msg.sender);
    }

    function confirmReceipt(string memory _item) public onlyBuyer(_item) {
        Listing storage listing = listings[_item];
        require(listing.isSoldStatus, "Item not sold");
        require(!listing.isDeliveredStatus, "Item already delivered");

        listing.isDeliveredStatus = true;
        escrowFunds[address(this)] -= listing.priceAmt;
        payable(listing.sellerAddr).transfer(listing.priceAmt);

        emit ItemConfirmed(_item, msg.sender);
    }

    function settleDispute(string memory _item, bool _isBuyerRight) public onlyAdmin {
        Listing storage listing = listings[_item];
        require(listing.isSoldStatus, "Item not sold");
        require(!listing.isDeliveredStatus, "Item already delivered");

        if (_isBuyerRight) {
            escrowFunds[address(this)] -= listing.priceAmt;
            payable(listing.buyerAddr).transfer(listing.priceAmt);
        } else {
            listing.isDeliveredStatus = true;
            escrowFunds[address(this)] -= listing.priceAmt;
            payable(listing.sellerAddr).transfer(listing.priceAmt);
        }

        emit DisputeSettled(_item, msg.sender, _isBuyerRight);
    }

    function getItemInfo(string memory _item) public view returns (address, uint256, address, bool, bool) {
        Listing storage listing = listings[_item];
        return (listing.sellerAddr, listing.priceAmt, listing.buyerAddr, listing.isSoldStatus, listing.isDeliveredStatus);
    }
}
