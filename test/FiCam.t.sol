// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FiCam} from "../contracts/FiCam.sol";
import {USDT} from "../contracts/usdt.sol";
import {MasterPool} from "../contracts/MasterPool.sol";
import "../contracts/interfaces/IFiCam.sol";

contract FiCamTest is Test {
    FiCam public FICAM;
    USDT public USDT_ERC;
    MasterPool public MONEY_POOL;
    uint256 ONE_USDT = 1_000_000;
    address public Deployer = address(0x1);
    address public buyer = address(0x2);
    address public hirer = address(0x3);
    ShippingParams public shipParams;
    constructor() {
        vm.startPrank(Deployer);
        FICAM = new FiCam();
        USDT_ERC = new USDT();
        MONEY_POOL = new MasterPool(address(USDT_ERC));
        FICAM.SetUsdt(address(USDT_ERC));
        FICAM.SetMasterPool(address(MONEY_POOL));
        vm.stopPrank();
    }
    function mintUSDT(address user, uint256 amount) internal {
        vm.startPrank(Deployer);
        USDT_ERC.mintToAddress(user, amount * ONE_USDT);
        vm.stopPrank();
    }

    function testOrder() public {
        vm.startPrank(Deployer);
        uint256 salePrice = 1250 *ONE_USDT;
        uint256 rentalPrice = 450 *ONE_USDT;
        uint256 monthlyPrice = 68 *ONE_USDT;
        uint256 sixMonthsPrice = 360 *ONE_USDT;
        uint256 yearlyPrice = 600 *ONE_USDT;
        uint256 storageQuantity= 100;
        uint256 _remainTime = 20000;
        FICAM.AdminAddProduct(
            "_imgUrl","_name","_desc","_advantages","_videoUrl",
            salePrice,rentalPrice,monthlyPrice,sixMonthsPrice,yearlyPrice,storageQuantity,
            _remainTime,true
        );
        uint256 salePrice1 = 200 *ONE_USDT;
        uint256 rentalPrice1 = 90 *ONE_USDT;
        uint256 monthlyPrice1 = 40 *ONE_USDT;
        uint256 sixMonthsPrice1 = 200 *ONE_USDT;
        uint256 yearlyPrice1 = 400 *ONE_USDT;
        uint256 storageQuantity1= 200;
        uint256 _remainTime1 = 40000;
        FICAM.AdminAddProduct(
            "_imgUrl1","_name1","_desc1","_advantages1","_videoUrl1",
            salePrice1,rentalPrice1,monthlyPrice1,sixMonthsPrice1,yearlyPrice1,storageQuantity1,
            _remainTime1,true
        );
        Product[] memory products = FICAM.UserViewProduct();
        assertEq(products.length,2,"should equal");
        assertEq(products[0].params.salePrice,1250 *ONE_USDT,"should equal");
        mintUSDT(address(buyer),10_000_000*ONE_USDT);
        mintUSDT(address(hirer),100_000_000*ONE_USDT);

        vm.stopPrank();
        shipParams = ShippingParams({
            firstName: "firstName",
            lastName: "lastName",
            email: "email",
            country: "country",
            city: "city",
            stateOrProvince: "stateOrProvince",
            postalCode: "postalCode",
            phone: "phone",
            addressDetail: "addressDetail"
        });

        buyProduct(products);
        hireProduct();
        hireAndBuyProducts();
    }
    function buyProduct(Product[] memory products)public{
        vm.startPrank(buyer);
        uint256 storageBefore = products[0].storageQuantity;
        assertEq(storageBefore,100,"should equal");
        assertEq(products[0].saleQuantity,0,"should equal");
        USDT_ERC.approve(address(FICAM),1_000_000*ONE_USDT);
        OrderInput[] memory orderInputs= new OrderInput[](1);
        OrderInput memory input0 = OrderInput({
            id: products[0].id,
            quantity: 5,
            typ: SUBCRIPTION_TYPE.NONE
        });
        orderInputs[0] = input0;
        FICAM.MakeOrder(orderInputs,shipParams,buyer);
        Product[] memory productsAfter = FICAM.UserViewProduct();
        uint256 storageAfter = productsAfter[0].storageQuantity;
        vm.stopPrank();       
        assertEq(storageAfter,95,"should equal");
        assertEq(productsAfter[0].saleQuantity,5,"should equal");
        assertEq(USDT_ERC.balanceOf(address(MONEY_POOL)),5*1250 *ONE_USDT,"should equal");
    }
    function hireProduct()public{
        vm.startPrank(hirer);
        vm.warp(1727930499); // 3/10/2024
        USDT_ERC.approve(address(FICAM),100_000_000*ONE_USDT);
        uint256 balBefore = USDT_ERC.balanceOf(address(MONEY_POOL));
        Product[] memory products = FICAM.UserViewProduct();
        uint256 storageBefore = products[0].storageQuantity;
        assertEq(storageBefore,95,"should equal");
        assertEq(products[0].saleQuantity,5,"should equal");
        assertEq(products[0].hireQuantity,0,"should equal");
        OrderInput[] memory orderInputs= new OrderInput[](1);
        OrderInput memory input0 = OrderInput({
            id: products[0].id,
            quantity: 10,
            typ: SUBCRIPTION_TYPE.MONTHLY
        });
        orderInputs[0] = input0;
        bytes32 orderId = FICAM.MakeOrder(orderInputs,shipParams,hirer);
        Product[] memory productsAfter = FICAM.UserViewProduct();
        uint256 storageAfter = productsAfter[0].storageQuantity;
        assertEq(storageAfter,85,"should equal");
        assertEq(productsAfter[0].saleQuantity,5,"should equal");
        assertEq(productsAfter[0].hireQuantity,10,"should equal");
        uint256 balAfter = USDT_ERC.balanceOf(address(MONEY_POOL));
        assertEq(balAfter,balBefore + 10*(450+68) *ONE_USDT,"should equal");
        (uint256 rentalAmount ,uint256 nextTime) = FICAM.getRentalInfo(hirer,orderId,products[0].id);
        assertEq(rentalAmount,68*10*ONE_USDT,"should equal");
        uint256 expectedNextTime = 1730608899; // 3/11/2024
        assertEq(nextTime,expectedNextTime ,"should equal"); 
        //renew
        FICAM.RenewSub(orderId,products[0].id);
        (rentalAmount ,nextTime) = FICAM.getRentalInfo(hirer,orderId,products[0].id);
        assertEq(rentalAmount,68*10*ONE_USDT,"should equal");
        expectedNextTime = 1733200899; // 3/12/2024
        assertEq(nextTime,expectedNextTime ,"should equal"); 
        vm.stopPrank();       

    }
    function hireAndBuyProducts()public{
        
    }
}
