// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;
import "./interfaces/IFiCam.sol";
import "@openzeppelin/contracts@v4.9.0/token/ERC20/IERC20.sol";

contract FiCam {
    mapping(uint256 => ShippingParams) public mShippingInfo;
    mapping(bytes32 => Order) mIDTOOrder; //mapping orderID to order
    bytes32[] public ListProductID;
    bytes32[] public ActiveProduct;
    mapping(address => bool) public IsAdmin;
    address public MasterPool;
    address public Owner;
    IERC20 public SCUsdt;
    address[] public Admins;
    mapping(bytes32 => Product) public mIDToProduct;
    uint256 public shippingCounter;
    mapping(uint256 => uint256) public mShippingInfoByOrder;
    mapping(address => uint256[]) public mShippingInfoByAddress;
    mapping(address => bytes32[]) public mAddressTOOrderID;
    mapping(bytes32 => uint256) public mProductViewCount; // productID => count
    mapping(bytes32 => uint256[]) public mProductSearchTrend; //  productID => timestamp[] // each timestamp = each count
    bytes32[] public OrderIDs;
    struct EventInput {
        address add;
        uint256 quantity;
        uint256 price;
        SubscriptionType subTyp;
        uint256 time;
        bytes32 id;
        address from;
        address to;
    }
    event eBuyProduct(EventInput eventOrder);

    constructor()payable{
        Owner = msg.sender;
        SCUsdt = IERC20(address(0x0000000000000000000000000000000000000002));

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
    function SetUsdt(address _usdt) external onlyOwner {
        SCUsdt = IERC20(_usdt);
    }
    function SetMasterPool(address _masterPool) external onlyOwner {
        MasterPool = _masterPool;
    }
    function SetAdmin(address _admin) external onlyOwner {
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
                monthlyPrice: _monthlyPrice,
                sixMonthsPrice: _sixMonthsPrice,
                yearlyPrice: _yearlyPrice
            }),
            storageQuantity: _storageQuantity,
            saleQuantity: 0,
            hireQuantity: 0,
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

    function GetProductById(bytes32 _id) public view returns (Product memory) {
        return mIDToProduct[_id];
    }

    function AdminUpdateProductInfo(
        bytes32 _id,
        string memory _imgUrl,
        string memory _desc,
        string memory _advantages,
        string memory _videoUrl,
        uint256 _salePrice,
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
        returns (Product[] memory _products)
    {
        _products = new Product[](ListProductID.length);
        for (uint i = 0; i < ListProductID.length; i++) {
            _products[i] = mIDToProduct[ListProductID[i]];
        }
        return _products;
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
    // Function to buy a product
    function Order(
        OrderInput[] memory orderInputs,
        ShippingParams memory shipParams,
        address to
    ) external {
        OrderProduct[] memory orderProducts = new OrderProduct[](orderInputs.length);
        uint totalPrice;
        for (uint i = 0; i < orderInputs.length; i++) {
            OrderInput memory input = orderInputs[i];
            require(
                mIDToProduct[input.id].id != bytes32(0),
                '{"from": "FiCam.sol", "code": 4, "message": "Invalid product ID or product does not exist"}'
            );
            require(uint256(input.typ) < 4,"Invalid subscription type");
            Product storage product = mIDToProduct[input.id];
            //
            if (input.typ == SubscriptionType.NONE) {
                require(product.saleQuantity > 0, "product sold out");
                product.storageQuantity -= 1;
                product.saleQuantity += 1; 
                totalPrice += product.params.salePrice;
            }else{
                uint256 rentalPrice = _rent(input);
                totalPrice += rentalPrice;
            }
            //
            orderProducts[i] = OrderProduct({
                idProduct:input.id,
                quantity:input.quantity,
                subType: input.typ
            });

            EventInput memory eventInput = EventInput({
                add: to,
                quantity: input.quantity,
                price: product.params.salePrice,
                subTyp: input.typ,
                time: block.timestamp,
                id: input.id,
                from: msg.sender,
                to: MasterPool
            });
            emit eBuyProduct(eventInput);

        }
        require(SCUsdt.transferFrom(msg.sender, MasterPool, totalPrice), "Token transfer failed");
        bytes32 orderId = keccak256(abi.encodePacked(to, orderInputs.length, block.timestamp));
        Order memory order = Order({
            id: orderId,
            customer: to,
            products: orderProducts,
            createAt: block.timestamp,
            shipInfo: shipParams
        });
        mIDTOOrder[orderId] = order;

    }
    function getShipInfo(bytes32 _orderId)public view returns(ShippingParams memory){
        return mIDTOOrder[_orderId].shipInfo;
    }
    function getmIDTOOrder(bytes32 _orderId)external view returns(Order memory){
        return mIDTOOrder[_orderId];
    }

    // Function to rent a product with a subscription
    function _rent(
        OrderInput memory input     
    ) internal returns(uint256 rentalPrice){
        Product storage product = mIDToProduct[input.id];
        require(product.hireQuantity > 0, "No products available for rent");

        if (SubscriptionType.MONTHLY == input.typ) {
            rentalPrice = product.params.monthlyPrice;
        } 
        if (SubscriptionType.SIXMONTHS == input.typ) {
            rentalPrice = product.params.sixMonthsPrice;
        } 
        if (SubscriptionType.YEARLY == input.typ) {
            rentalPrice = product.params.yearlyPrice;
        } 
        product.storageQuantity -= 1;
        product.hireQuantity += 1; 
    }

    function getProductTrend(
        bytes32 _productID,
        uint256 _from,
        uint256 _to
    ) public view returns (uint256 count) {
        uint256[] memory arr = mProductSearchTrend[_productID];
        count = countElementsInRange(_from,_to,arr);
    }

    function countElementsInRange(uint beginTime, uint endTime,uint256[] memory sortedArray) public view returns (uint256 count) {
        require(beginTime <= endTime, "Invalid time range");

        uint256 startIndex = findIndex(beginTime, true,sortedArray);
        uint256 endIndex = findIndex(endTime, false,sortedArray);

        if (startIndex <= endIndex) {
            count = endIndex - startIndex + 1;
        }
    }

    // Helper function to find the index for the given value
    function findIndex(uint value, bool isLowerBound,uint256[] memory sortedArray) internal view returns (uint256) {
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

}