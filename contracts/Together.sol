// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {IERC1271Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC1271Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ERC721HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import {SafeMath} from "@openzeppelin/contracts2/math/SafeMath.sol";
import {IWETH} from "./IWETH.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "sgn-v2-contracts/contracts/message/libraries/MessageSenderLib.sol";


contract Together is ReentrancyGuardUpgradeable, ERC721HolderUpgradeable,IERC1271Upgradeable {
    using SafeMath for uint256;

    uint256  constant CONST_SQRTNUMBER = 18446744073709551616;   
    uint256  constant CONST_PROPORTION = 10e4;
    uint256  constant MIN_FEE = 500;   //手续费的下限

    address public immutable togetherFactory;
    address public immutable togetherDAO;

    IWETH public immutable weth;

    IERC721Metadata public nftContract;    
    uint256 public tokenId;      
    uint256 public createAt;           //创建提案时间
    IERC20 public token;               //募资token  
    uint256 public preAmount;          //需要募集金额 
    uint256 public actualAmount;       //已经募集金额 
    uint256 public foundExpiresAt;     //秒   募资截止时间  
    uint256 public buyExpiresAt;       //秒   购买NFT截止时间        
    uint256 public step ;              // 0 募资；1 跨链; 2 购买；3 售卖； 4 跨回； 5 领取
    uint256[]  public proportionList;   
    
    address public messageBus;
    uint256 public crossChainAmount;
    // ============ Public Mutable Storage ============    
    mapping(address =>uint256) public contributions;  
    address[] public conributorList;  
    mapping(address => uint256) public income;  
    mapping(address => bool) public claimed;
    uint256 public totalfee;
    
    modifier onlyPartyDAO() {
        require(msg.sender == togetherDAO,"No authorization");
        _;
    }
    // ======== Constructor =========
    constructor(
        address _togetherDAO,     
        address _weth,
        address _messageBus
    ) {
        togetherFactory = msg.sender;
        togetherDAO = _togetherDAO;     
        weth = IWETH(_weth);
        messageBus = _messageBus;
    }

    function __Party_init(
        address _nftContract,     
        address _token,
        uint256 _tokenAmount,
        uint256 _secondsToTimeoutFoundraising,
        uint256 _secondsToTimeoutBuy
    ) internal {
        require(msg.sender == partyFactory,"only factory can init");
        require(_token != address(0) && _tokenAmount != 0,"invalid parameter");

        __ReentrancyGuard_init();
        __ERC721Holder_init();
       
        nftContract = IERC721Metadata(_nftContract);
        token = IERC20(_tokenGate.addr); 
        preAmount = _tokenAmount;
        foundExpiresAt = block.timestamp + _secondsToTimeoutFoundraising;
        buyExpiresAt =  block.timestamp + _secondsToTimeoutBuy;
    }

    
    function _contribute(address _token,uint256 _amount) internal {
        require(step ==0,"not active");
        address _contributor = msg.sender;         
        require(preAmount >= _amount && _amount > 0,"Invalid parameter"); 
        require(IERC20(proposal.token).transfer(address(this),_amount),"Transfer failed");    
         
        actualAmount = actualAmount.add(_amount);

        contributions[_contributor] = _amount;
        conributorList.push(_contributor);
    }

    // ======== External: Cross chain =========

    function sendMessageWithTransfer(
        address _receiver,  
        address _token,  
        uint256 _amount,  
        uint64 _dstChainId,  
        uint32 _maxSlippage,  
        MessageSenderLib.BridgeType _bridgeType,  
        address[] calldata _accounts,  
        uint256[] calldata _amounts  
    ) external payable {
        
        // IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        
        bytes memory message = abi.encode(address(this));
        
        MessageSenderLib.sendMessageWithTransfer(
            _receiver,
            _token,
            _amount,
            _dstChainId,
            1,
            _maxSlippage,
            message,
            _bridgeType,
            messageBus,
            msg.value
        );
    }

   function executeMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message
    ) external onlyMessageBus returns (bool) {
       
        address memory transfer = abi.decode((_message), (address));
       
        crossChainAmount = _amount;
        return true;
    }

    // ======== External: Return bill =========
     function returnIncome(uint256 _totalfee) external { 
        totalfee = _totalfee;  
      
    //    for(uint256 i=0; i < investors.length; i++){
    //      //计算手续费
    //      address investor = investors[i];   
    //      uint256 proportion = feeProportion(_index, investor);
    //      uint256 fee =proportion.mul(_totalfee).div(CONST_PROPORTION); 
    //     //  //设置手续费的下限
    //     //  if (fee < MIN_FEE){
    //     //      fee = MIN_FEE;
    //     //  } 

    //      uint256 income = number.mul(investProportion(_index,investor)).sub(fee);   
         
    //      //平摊手续费          
    //      require(IERC20(proposal.token).transfer(investor,income),"ReturnIncome failed"); 
    //     income[investor] = income;
    //    }       
    }
   
     // ======== External: Claim =========
    function _claim() external nonReentrant { 
        uint256 _fee = totalfee.mul(feeProportion);       

        address _contributor = msg.sender;
        uint256 _amount = income[_contributor];
        require( _amount > 0,"No income");
        uint256 _income = _amount.mul(CONST_PROPORTION).sub(_fee).dev(_fee);
        
        require(IERC20(token).transferFrom(address(this),_contributor,_income),"Claim failed"); 
        income[_contributor] = 0 ;

    }

      //计算投资占比 * 10e4
    function investProportion (address _contributor) internal view returns (uint256 _proportion){     
        _proportion = contributions[_contributor].mul(CONST_PROPORTION).div(actualAmount)  ;     
       return  _proportion;
    }

    //计算手续费比例 * 10e4
     function feeProportion (address _contributor) internal  returns (uint256 _proportion){ 
       address[] memory contributorList = conributorList;  
       address[] memory proportionList ;     
       for(uint256 i=0; i < contributorList.length; i++){
          uint256  _proportion = investProportion(investors[i]).mul(CONST_SQRTNUMBER);
          uint256 number = sqrt(_proportion);           
          proportionList.push(number);
       }       
       uint256 sum = sum(proportionList);        
       uint256 amount =sqrt(investProportion(_contributor).mul(CONST_SQRTNUMBER)); 
       _proportion = amount.mul(CONST_PROPORTION).div(sum);

       return  _proportion;
    }

  
    function emergencyWithdrawEth(uint256 _value) external onlyPartyDAO {
        _transferETHOrWETH(partyDAOMultisig, _value);
    }

    /**
     * @notice Escape hatch: in case of emergency,
     * PartyDAO can use emergencyCall to call an external contract
     * (e.g. to withdraw a stuck NFT or stuck ERC-20s)
     */
    function emergencyCall(address _contract, bytes memory _calldata)
        external
        onlyPartyDAO
        returns (bool _success, bytes memory _returnData)
    {
        (_success, _returnData) = _contract.call(_calldata);
        require(_success, string(_returnData));
    }

    
    // ============ Internal: TransferEthOrWeth ============  
    function _transferETHOrWETH(address _to, uint256 _value) internal {
        // skip if attempting to send 0 ETH
        if (_value == 0) {
            return;
        }      
        if (_value > address(this).balance) {
            _value = address(this).balance;
        }       
        if (!_attemptETHTransfer(_to, _value)) {           
            weth.deposit{value: _value}();
            weth.transfer(_to, _value);           
        }
    }

    function _attemptETHTransfer(address _to, uint256 _value)
        internal
        returns (bool)
    {    
        (bool success, ) = _to.call{value: _value, gas: 30000}("");
        return success;
    }

    // eip1271
    function isValidSignature(
        bytes memory _message,
        bytes memory _signature
    )
        public
        override
        view
        returns (bytes4 magicValue)
    {
        bytes32 messageHash = keccak256(abi.encodePacked(_message));
        address signer = messageHash.recover(_signature);
        if (signer == owner) {
        return MAGICVALUE;
        } else {
        return INVALID_SIGNATURE;
        }
    }

//================== util========================
    function sqrt(uint256 y) internal pure returns (uint256) {
        if (y > 3) {
            uint256 z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
            return z;
        } else if (y != 0) {
            return 1;
        } else {
            return 0;
        }
    }

    //
    function sum(uint256[] memory _arr) internal pure returns (uint256 s) {
        for (uint256 i = 0; i < _arr.length; i++){            
            s.add( _arr[i]);
        }            
    }

}
