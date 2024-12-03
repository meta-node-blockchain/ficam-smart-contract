// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;
import "./interfaces/IFiCam.sol";
import "@openzeppelin/contracts@v4.9.0/token/ERC20/IERC20.sol";
import "./libs/ConvertTime.sol";
import "./abstract/use_pos.sol";

// import "forge-std/console.sol";
contract FiCam is UsePos{
    bytes32[] public ListProductID;
    bytes32[] public ActiveProduct;
    address public MasterPool;
    address public Owner;
    IERC20 public SCUsdt;
    address[] public Admins;
    address[] public Users;
    uint256 public shippingCounter;
    mapping(address => bool) public IsAdmin;
    mapping(uint256 => ShippingParams) public mShippingInfo;
    mapping(bytes32 => Order) mIDTOOrder; //mapping orderID to order
    mapping(bytes32 => Product) public mIDToProduct;
    mapping(uint256 => uint256) public mShippingInfoByOrder;
    mapping(address => uint256[]) public mShippingInfoByAddress;
    mapping(address => bytes32[]) public mAddressTOOrderID;
    mapping(bytes32 => uint256) public mProductViewCount; // productID => count
    mapping(bytes32 => uint256[]) public mProductSearchTrend; //  productID => timestamp[] // each timestamp = each count
    mapping(address => mapping(bytes32 =>mapping(bytes32 => uint256))) firstTimePay; //hirer => orderId => idProduct => first time pay
    mapping(address => mapping(bytes32 => mapping(bytes32 => uint256))) nextTimePay;  //hirer => orderId => idProduct => next time pay
    mapping(address => mapping(bytes32 => mapping(bytes32 => uint256))) mRentalPay; //hirer => orderId => idProduct => rental pay
    mapping(address => mapping(bytes32 => mapping(bytes32 => OrderInput))) mRentalInput; //hirer => orderId => idProduct => rental pay
    mapping(bytes32 => bytes) public mCallData;
    bytes32[] public OrderIDs;
    address public POS;
    struct EventInput {
        address add;
        uint256 quantity;
        uint256 price;
        SUBCRIPTION_TYPE subTyp;
        uint256 time;
        bytes32 id;
        address from;
        address to;
        bytes32 idPayment;
    }
    enum ExecuteOrderType {
        Order,
        Renew
    }
    event eBuyProduct(EventInput eventOrder);
    event Hire(
        address buyer,
        bytes32 orderId,
        bytes32 productId,
        uint256 firstTimePay,
        uint256 nextTimePay,
        uint256 amount,
        uint256 typSub,
        bytes32 idPayment
    );
    event EmailOrder(string email, Order order,uint256 totalPrice);
    constructor()payable{
        Owner = msg.sender;
        SCUsdt = IERC20(address(0x0000000000000000000000000000000000000002));
        SetAdmin(msg.sender);
    }
    modifier onlyOwner() {
        require(
            Owner == msg.sender,
            '{"from": "FiCam.sol", "code": 1, "message": "Invalid caller-Only Owner"}'
        );
        _;
    }
    modifier onlyAdmin() {
        require(
            IsAdmin[msg.sender] == true, 
            '{"from": "FiCam.sol", "code": 2, "message": "Invalid caller-Only Admin"}'
        );
        _;
    }
    modifier onlyPOS() {
        require(
            msg.sender == POS,
            '{"from": "FiCam.sol", "code": 3, "message": "Only POS"}'
        );
        _;
    }
    function SetPOS(address _pos) external onlyOwner {
        POS = _pos;
    }
    function SetUsdt(address _usdt) external onlyOwner {
        SCUsdt = IERC20(_usdt);
    }
    function SetMasterPool(address _masterPool) external onlyOwner {
        MasterPool = _masterPool;
    }
    function SetAdmin(address _admin) public onlyOwner {
        IsAdmin[_admin] = true;
        Admins.push(_admin);
    }
    function AdminAddProduct(
        string memory _imgUrl,
        string memory _name,
        string memory _desc,
        string memory _advantages,
        string memory _videoUrl,
        uint256 _salePrice,
        uint256 _rentalPrice,
        uint256 _monthlyPrice,
        uint256 _sixMonthsPrice,
        uint256 _yearlyPrice,
        uint256 _storageQuantity,
        uint256 _remainTime,
        bool    _active
    ) external onlyAdmin {
        bytes32 idPro = keccak256(
            abi.encodePacked(_imgUrl, _name, _desc)
        );
        
        mIDToProduct[idPro] = Product({
            id: idPro,
            params: createProductParams({
                imgUrl: _imgUrl,
                name: _name,
                desc: bytes(_desc),
                advantages: _advantages,
                videoUrl: _videoUrl,
                salePrice: _salePrice,
                rentalPrice: _rentalPrice,
                monthlyPrice: _monthlyPrice,
                sixMonthsPrice: _sixMonthsPrice,
                yearlyPrice: _yearlyPrice
            }),
            storageQuantity: _storageQuantity,
            saleQuantity: 0,
            hireQuantity: 0,
            returnHiredQuantity:0,
            remainTime: _remainTime,
            updateAt: block.timestamp,
            active: _active
        });

        if (_active == true) {
            ActiveProduct.push(idPro);
        }

        ListProductID.push(idPro);
    }
    function AdminActiveProduct(bytes32 _id) external onlyAdmin returns (bool) {
        mIDToProduct[_id].active = true;
        for (uint256 i = 0; i < ActiveProduct.length; i++) {
            if (ActiveProduct[i] == _id) {
                return true;
            }
        }
        ActiveProduct.push(_id);
        return true;
    }
    function AdminDeactiveProduct(
        bytes32 _id
    ) external onlyAdmin returns (bool) {
        mIDToProduct[_id].active = false;
        for (uint256 i = 0; i < ActiveProduct.length; i++) {
            if (ActiveProduct[i] == _id) {
                if (i < ActiveProduct.length - 1) {
                    ActiveProduct[i] = ActiveProduct[ActiveProduct.length - 1];
                }
                ActiveProduct.pop();
                return true;
            }
        }
        return true;
    }
    function AdminUpdateProductInfo(
        bytes32 _id,
        string memory _imgUrl,
        string memory _desc,
        string memory _advantages,
        string memory _videoUrl,
        uint256 _salePrice,
        uint256 _rentalPrice,
        uint256 _monthlyPrice,
        uint256 _sixMonthsPrice,
        uint256 _yearlyPrice,
        uint256 _storageQuantity,
        uint256 _remainTime
    ) external onlyAdmin returns (bool) {
        Product storage product = mIDToProduct[_id];
        product.params.imgUrl = _imgUrl;
        product.params.desc = bytes(_desc);
        product.params.advantages = _advantages;
        product.params.videoUrl = _videoUrl;
        product.params.salePrice = _salePrice;
        product.params.rentalPrice = _rentalPrice;
        product.params.monthlyPrice = _monthlyPrice;
        product.params.sixMonthsPrice = _sixMonthsPrice;
        product.params.yearlyPrice = _yearlyPrice;
        product.storageQuantity = _storageQuantity;
        product.remainTime = _remainTime;
        product.updateAt = block.timestamp;
        return true;
    }
    function AdminEditUpdateAt(
        bytes32 _id,
        uint256 _updateAt
    ) external onlyAdmin returns (bool) {
        mIDToProduct[_id].updateAt = _updateAt;
        return true;
    }
    function AdminViewProduct()
        external
        view
        onlyAdmin
        returns (Product[] memory products)
    {
        products = new Product[](ListProductID.length);
        for (uint i = 0; i < ListProductID.length; i++) {
            products[i] = mIDToProduct[ListProductID[i]];
        }
        return products;
    }
    function UserViewProduct()
        external
        view
        returns (Product[] memory _products)
    {
        _products = new Product[](ActiveProduct.length);
        for (uint i = 0; i < ActiveProduct.length; i++) {
            _products[i] = mIDToProduct[ActiveProduct[i]];
        }
        return _products;
    }
    function ViewProducts(
        uint256 _updateAt,
        uint256 _index,
        uint256 _limit
    ) external view returns (Product[] memory rs, bool isMore, uint lastIndex) {
        Product[] memory ps = new Product[](_limit);
        isMore = false;
        uint index;
        while (_index < ActiveProduct.length) {
            if (_updateAt <= mIDToProduct[ActiveProduct[_index]].updateAt) {
                if (index < _limit) {
                    ps[index] = mIDToProduct[ActiveProduct[_index]];
                    lastIndex = _index;
                    index++;
                } else {
                    isMore = true;
                    break;
                }
            }
            _index++;
        }

        rs = new Product[](index);
        for (uint i; i < index; i++) {
            rs[i] = ps[i];
        }
    }
    function ViewProduct(bytes32 _id) public view returns (Product memory rs) {
        return mIDToProduct[_id];
    }
    function updateViewCount(bytes32 _productID) public {
        mProductViewCount[_productID]++;
        mProductSearchTrend[_productID].push(block.timestamp);
    }
    function getProductViewCount(
        bytes32 _productID
    ) public view returns (uint256) {
        return mProductViewCount[_productID];
    }
    function getProductTrend(
        bytes32 _productID
    ) public view returns (uint256[] memory) {
        return mProductSearchTrend[_productID];
    }
    function MakeOrder(
        OrderInput[] memory orderInputs,
        ShippingParams memory shipParams,
        address to
    ) external returns(bytes32){
        bytes32 orderId = keccak256(abi.encodePacked(to, orderInputs.length, block.timestamp));
        uint totalPrice;
        OrderDetail[] memory orderDetails = new OrderDetail[](orderInputs.length);
        for (uint i = 0; i < orderInputs.length; i++) {
            OrderInput memory input = orderInputs[i];
            require(
                mIDToProduct[input.id].id != bytes32(0),
                '{"from": "FiCam.sol", "code": 4, "message": "Invalid product ID or product does not exist"}'
            );
            require(uint256(input.typ) < 4,"Invalid subscription type");
            Product storage product = mIDToProduct[input.id];
            require(product.storageQuantity > 0, "product storage is not enough");
            //
            if (input.typ == SUBCRIPTION_TYPE.NONE) {
                product.storageQuantity -= input.quantity;
                product.saleQuantity += input.quantity; 
                totalPrice += product.params.salePrice * input.quantity;
            }else{
                uint256 rentalPrice = _rent(input,orderId,to);
                totalPrice += rentalPrice;
            }
            EventInput memory eventInput = EventInput({
                add: to,
                quantity: input.quantity,
                price: product.params.salePrice,
                subTyp: input.typ,
                time: block.timestamp,
                id: input.id,
                from: msg.sender,
                to: MasterPool,
                idPayment: bytes32(0)
            });
            emit eBuyProduct(eventInput);
            OrderDetail memory orderDetail = OrderDetail({
                id : orderInputs[i].id,
                quantity : orderInputs[i].quantity,
                typ : orderInputs[i].typ,
                productName : product.params.name,
                imgUrl : product.params.imgUrl
            });
            orderDetails[i]=orderDetail;
        }
        require(SCUsdt.transferFrom(msg.sender, MasterPool, totalPrice), "Token transfer failed");
        Order memory order = Order({
            id: orderId,
            customer: to,
            products: orderDetails,
            createAt: block.timestamp,
            shipInfo: shipParams,
            shippingFee: 5
        });
        mIDTOOrder[orderId] = order;
        mAddressTOOrderID[to].push(orderId);
        Users.push(to);
        OrderIDs.push(orderId);
        emit EmailOrder(shipParams.email,order,totalPrice);
        return orderId;
    }
    function _rent(
        OrderInput memory input,
        bytes32 _orderId,
        address to
    ) internal returns(uint256 rentPrice){
        Product storage product = mIDToProduct[input.id];
        uint256 rentalAmount;
        if (SUBCRIPTION_TYPE.MONTHLY == input.typ) {
            rentalAmount = product.params.monthlyPrice * input.quantity;
            rentPrice = product.params.rentalPrice * input.quantity + rentalAmount;
        } 
        if (SUBCRIPTION_TYPE.SIXMONTHS == input.typ) {
            rentalAmount = product.params.sixMonthsPrice * input.quantity;
            rentPrice = product.params.rentalPrice * input.quantity + rentalAmount;
        } 
        if (SUBCRIPTION_TYPE.YEARLY == input.typ) {
            rentalAmount = product.params.yearlyPrice * input.quantity;
            rentPrice = product.params.rentalPrice * input.quantity + rentalAmount;
        } 
        product.storageQuantity -= input.quantity;
        product.hireQuantity += input.quantity; 
        firstTimePay[to][_orderId][input.id] = block.timestamp;
        nextTimePay[to][_orderId][input.id] = DateTimeLibrary.addMonths(block.timestamp,getMonth(input.typ));
        mRentalPay[to][_orderId][input.id] = rentalAmount;
        mRentalInput[to][_orderId][input.id] = input;
        emit Hire(
            to,
            _orderId,
            input.id,
            block.timestamp,
            nextTimePay[to][_orderId][input.id],
            uint256(input.typ),
            rentalAmount,
            bytes32(0)
        );
    }
    function getRentalInfo(address hirer, bytes32 _orderId, bytes32 _idProduct)external view returns(uint256 rentalAmount,uint256 nextTime){
        rentalAmount = mRentalPay[hirer][_orderId][_idProduct] ;
        nextTime = nextTimePay[hirer][_orderId][_idProduct];
    }
    function RenewSub(bytes32 _orderId, bytes32 _idProduct) external returns(bool) {
        address to = mIDTOOrder[_orderId].customer;
        uint256 rentalAmount = mRentalPay[to][_orderId][_idProduct];
        SCUsdt.transferFrom(msg.sender, MasterPool, rentalAmount);
        SUBCRIPTION_TYPE typSub = mRentalInput[to][_orderId][_idProduct].typ;
        nextTimePay[to][_orderId][_idProduct] = DateTimeLibrary.addMonths(nextTimePay[to][_orderId][_idProduct],getMonth(typSub));
        emit Hire(
            to,
            _orderId,
            _idProduct,
            block.timestamp,
            nextTimePay[to][_orderId][_idProduct],
            rentalAmount,
            uint256(typSub),
            bytes32(0)
        );
        return true;
    }
    function getMonth(SUBCRIPTION_TYPE typ)internal pure returns(uint256 month){
        if (SUBCRIPTION_TYPE.MONTHLY == typ) {
            month = 1;
        }
        if (SUBCRIPTION_TYPE.YEARLY == typ) {
            month = 6;
        }
        if (SUBCRIPTION_TYPE.YEARLY == typ) {
            month = 12;
        }
    }
    function getShipInfo(bytes32 _orderId)public view returns(ShippingParams memory){
        return mIDTOOrder[_orderId].shipInfo;
    }
    function getmIDTOOrder(bytes32 _orderId)external view returns(Order memory){
        return mIDTOOrder[_orderId];
    }
    function getProductTrendByTime(
        bytes32 _productID,
        uint256 _from,
        uint256 _to
    ) public view returns (uint256 count) {
        uint256[] memory arr = mProductSearchTrend[_productID];
        count = countElementsInRange(_from,_to,arr);
    }
    function countElementsInRange(uint beginTime, uint endTime,uint256[] memory sortedArray) public pure returns (uint256 count) {
        require(beginTime <= endTime, "Invalid time range");

        uint256 startIndex = findIndex(beginTime, true,sortedArray);
        uint256 endIndex = findIndex(endTime, false,sortedArray);

        if (startIndex <= endIndex) {
            count = endIndex - startIndex + 1;
        }
    }
    function findIndex(uint value, bool isLowerBound,uint256[] memory sortedArray) internal pure returns (uint256) {
        uint left = 0;
        uint right = sortedArray.length;

        while (left < right) {
            uint mid = left + (right - left) / 2;

            if (isLowerBound) {
                // Find the lower bound (first element >= value)
                if (sortedArray[mid] < value) {
                    left = mid + 1;
                } else {
                    right = mid;
                }
            } else {
                // Find the upper bound (last element <= value)
                if (sortedArray[mid] > value) {
                    right = mid;
                } else {
                    left = mid + 1;
                }
            }
        }

        return isLowerBound ? left : (left == 0 ? 0 : left - 1);
    }
    function AdminViewOrder(address _to) external view onlyAdmin returns (Order[] memory orders){
        orders = new Order[](mAddressTOOrderID[_to].length);
        for (uint256 index = 0; index < mAddressTOOrderID[_to].length; index++) {
            orders[index] = mIDTOOrder[mAddressTOOrderID[_to][index]];
        }
    }
    function GetMyOrder(uint32 _page,uint returnRIP) 
    external 
    view 
    returns(bool isMore, Order[] memory arrayOrder) {
        
        bytes32[] memory idArr = new bytes32[](mAddressTOOrderID[msg.sender].length);
        idArr = mAddressTOOrderID[msg.sender];
        // uint256 length = idArr.length;
        if (_page * returnRIP > idArr.length + returnRIP) { 
            return(false, arrayOrder);
        } else {
            if (_page*returnRIP < idArr.length ) {
                isMore = true;
                arrayOrder = new Order[](returnRIP);
                for (uint i = 0; i < arrayOrder.length; i++) {
                    arrayOrder[i] = mIDTOOrder[idArr[_page*returnRIP - returnRIP +i]];
                }
                return (isMore, arrayOrder);
            } else {
                isMore = false;
                arrayOrder = new Order[](returnRIP -(_page*returnRIP - idArr.length));
                for (uint i = 0; i < arrayOrder.length; i++) {
                    arrayOrder[i] = mIDTOOrder[idArr[_page*returnRIP - returnRIP +i]];
                }
                return (isMore, arrayOrder);
            }
        }
    }
    function CallDataOrder(
        OrderInput[] memory _input,
        ShippingParams memory _shipParams,       
        address _address
    ) public pure returns (bytes memory action) {
        return abi.encode(_input,_shipParams, _address);
    }
    function CallDataRenew(
        bytes32 _orderId, 
        bytes32 _idProduct
    ) public pure returns (bytes memory callData) {
        return abi.encode(_orderId,_idProduct);
    }
    function GetCallData(
        bytes memory action,
        ExecuteOrderType typ
    )public pure returns(bytes memory callData){
        return abi.encode(action,typ);
    }
    function GetCallDataFE(bytes32 _idCalldata)public view returns(bytes memory){
        return mCallData[_idCalldata];
    }
    function SetCallDataFE(
        OrderInput[] memory _input,
        ShippingParams memory _shipParams,       
        address _address,
        ExecuteOrderType typ
    )public returns(bytes32 idCallData){
        bytes memory action = abi.encode(_input,_shipParams, _address);
        bytes memory callData = abi.encode(action,typ);
        idCallData = keccak256(abi.encodePacked(_address,typ,block.timestamp));
        mCallData[idCallData] = callData;
        return idCallData;
    }
    function ExecuteOrder(
        bytes memory callData,
        bytes32 orderId,
        uint256 paymentAmount
    ) public override onlyPOS returns (bool) {
        (bytes memory action, ExecuteOrderType typ) = abi.decode(
            callData,
            (bytes, ExecuteOrderType)
        );
        if (typ == ExecuteOrderType.Order) {
            return OrderLock(action, orderId, paymentAmount);
        }

        if (typ == ExecuteOrderType.Renew) {
            return RenewSubLock(action, orderId, paymentAmount);
        }
        return false;
    }
    function OrderLock(
        bytes memory callData,
        bytes32 idPayment,
        uint256 paymentAmount
    ) internal returns (bool) {
        (OrderInput[] memory orderInputs, ShippingParams memory shipParams,address to) = abi.decode(
            callData,
            (OrderInput[],ShippingParams, address)
        );

        bytes32 orderId = keccak256(abi.encodePacked(to, orderInputs.length, block.timestamp));
        uint totalPrice;
        OrderDetail[] memory orderDetails = new OrderDetail[](orderInputs.length);
        for (uint i = 0; i < orderInputs.length; i++) {
            OrderInput memory input = orderInputs[i];
            require(
                mIDToProduct[input.id].id != bytes32(0),
                '{"from": "FiCam.sol", "code": 4, "message": "Invalid product ID or product does not exist"}'
            );
            require(uint256(input.typ) < 4,"Invalid subscription type");
            Product storage product = mIDToProduct[input.id];
            require(product.storageQuantity > 0, "product storage is not enough");
            //
            if (input.typ == SUBCRIPTION_TYPE.NONE) {
                product.storageQuantity -= input.quantity;
                product.saleQuantity += input.quantity; 
                totalPrice += product.params.salePrice * input.quantity;
            }else{
                uint256 rentalPrice = _rent(input,orderId,to);
                totalPrice += rentalPrice;
            }
            EventInput memory eventInput = EventInput({
                add: to,
                quantity: input.quantity,
                price: product.params.salePrice,
                subTyp: input.typ,
                time: block.timestamp,
                id: input.id,
                from: msg.sender,
                to: MasterPool,
                idPayment: idPayment
            });
            emit eBuyProduct(eventInput);
            OrderDetail memory orderDetail = OrderDetail({
                id : orderInputs[i].id,
                quantity : orderInputs[i].quantity,
                typ : orderInputs[i].typ,
                productName : product.params.name,
                imgUrl : product.params.imgUrl
            });
            orderDetails[i]=orderDetail;
        }
        require(
            paymentAmount >= totalPrice , 
            '{"from": "FiCam.sol", "code": 8, "message": "Insufficient payment amount"}'
        );
        Order memory order = Order({
            id: orderId,
            customer: to,
            products: orderDetails,
            createAt: block.timestamp,
            shipInfo: shipParams,
            shippingFee: 5
        });
        mIDTOOrder[orderId] = order;
        mAddressTOOrderID[to].push(orderId);
        Users.push(to);
        OrderIDs.push(orderId);
        emit EmailOrder(shipParams.email,order,paymentAmount);
        return true;    
    }
    function RenewSubLock(
        bytes memory callData,
        bytes32 idPayment,
        uint256 paymentAmount       
    ) internal returns(bool) {
        (bytes32 _orderId, bytes32 _idProduct) = abi.decode(
            callData,
            (bytes32,bytes32)
        );
        address to = mIDTOOrder[_orderId].customer;
        uint256 rentalAmount = mRentalPay[to][_orderId][_idProduct];
        require(
            paymentAmount >= rentalAmount,
            '{"from": "FiCam.sol", "code": 8, "message": "Insufficient payment amount"}'

        );
        SUBCRIPTION_TYPE typSub = mRentalInput[to][_orderId][_idProduct].typ;
        nextTimePay[to][_orderId][_idProduct] = DateTimeLibrary.addMonths(nextTimePay[to][_orderId][_idProduct],getMonth(typSub));
        emit Hire(
            to,
            _orderId,
            _idProduct,
            block.timestamp,
            nextTimePay[to][_orderId][_idProduct],
            rentalAmount,
            uint256(typSub),
            idPayment
        );
        return true;
    }
}