// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

struct Product {
    bytes32 id;
    createProductParams params;
    uint256 storageQuantity;
    uint256 saleQuantity;
    uint256 hireQuantity;
    uint256 returnHiredQuantity;
    uint256 remainTime;
    uint256 updateAt;
    bool active;
}

struct createProductParams {
    string imgUrl;
    string name;
    bytes desc;
    string advantages;
    string videoUrl;
    uint256 salePrice;
    uint256 rentalPrice;
    uint256 monthlyPrice;
    uint256 sixMonthsPrice;
    uint256 yearlyPrice;
}

struct Order {
    bytes32 id;
    address customer;
    OrderDetail[] products;
    uint256 createAt;
    ShippingParams shipInfo;
    uint256 shippingFee;
}

struct OrderInput {
    bytes32 id;
    uint256 quantity;
    SUBCRIPTION_TYPE typ;
}
struct OrderDetail {
    bytes32 id;
    uint256 quantity;
    SUBCRIPTION_TYPE typ;
    string productName;
    string imgUrl;
}

struct ShippingParams {
    string firstName;
    string lastName;
    string email;
    string country;
    string city;
    string stateOrProvince;
    string postalCode;
    string phone;
    string addressDetail;
}

enum SUBCRIPTION_TYPE {
    NONE,
    MONTHLY,
    SIXMONTHS,
    YEARLY
}
