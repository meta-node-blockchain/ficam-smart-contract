// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;
    struct Product{
        bytes32 id;
        createProductParams params;
        uint256 storageQuantity;
        uint256 saleQuantity;
        uint256 hireQuantity;
        uint256 remainTime;
        uint256 updateAt;
        bool    active;
    }
    struct createProductParams {
        string  imgUrl;
        string  name;
        bytes   desc;
        string  advantages;
        string  videoUrl;
        uint256 salePrice;
        uint256 monthlyPrice;
        uint256 sixMonthsPrice;
        uint256 yearlyPrice;
    }
    struct OrderProduct {
        bytes32           idProduct;
        uint256           quantity;
        SubscriptionType  subType;
    }
    struct Order {
        bytes32 id;
        address customer;
        OrderProduct[] products;
        uint256 createAt;
        ShippingParams shipInfo;
    }
    struct OrderInput {
        bytes32 id;
        uint256 quantity;
        SubscriptionType typ;
    }
    // struct ShippingInfo {
    //     uint256 id;
    //     uint256 orderID;
    //     address userAddress;
    //     ShippingParams params;
    // }
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
    enum SubscriptionType {
        NONE,
        MONTHLY,
        SIXMONTHS,
        YEARLY
    }
