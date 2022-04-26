// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;


import {Together} from "./Together.sol"; 
import {IAllowList} from "./IAllowList.sol";

contract TogetherInvest is Together{
 
  // PartyBuy version 1
    uint16 public constant VERSION = 1;  
    IAllowList public immutable allowList; 
   
    // ============ Events ============
    event Contributed(
        address proposal,
        address nftContract,
        address indexed contributor,
        uint256 amount   
        
    );
    event Expired(address triggeredBy);
 
    event Claimed(
        address proposal,
        address indexed contributor,
        address token,
        uint256 tokenAmount
    );
    // ======== Modifiers =========
    modifier onlyPartyDAO() {
        require(
            msg.sender == partyDAOMultisig,
            "Party:: only PartyDAO multisig"
        );
        _;
    }    
    // ======== Constructor =========
    constructor(
        address _togetherDAO,      
        address _weth,
        address _allowList,
        address  _messageBus
      
    )Together(_togetherDAO,_weth,_messageBus){
       allowList = _allowList;
    }

    // ======== Initializer =========

    function initialize(
        address _nftContract,     
        address _token,
        uint256 _tokenAmount,
        uint256 _secondsToTimeoutFoundraising,
        uint256 _secondsToTimeoutBuy
    ) external initializer {        
        require( _tokenAmount > 0, "tokenAmount must higher than 0");      
        __Party_init(_nftContract, _token, _tokenAmount, _secondsToTimeoutFoundraising,_secondsToTimeoutBuy);       
    }

    
    function contribute(uint256 _amount) external payable nonReentrant {   
        require( "PartyBuy::contribute: cannot contribute more than max");        
        _contribute();
        emit Contributed(
            address(this),
            nftContract,
            _contributor,
            _amount
           
        );
    }


    function claim() external nonReentrant {

        _claim();        
     
        emit Claimed(
            address(this),
            _contributor,
            token,
           _amount
        );

    }
  
 


   /**
    *过了sellDDL,所有用户可以收回他们的资金，任何贡献者都可以调用
    *设置
    */

   
}
