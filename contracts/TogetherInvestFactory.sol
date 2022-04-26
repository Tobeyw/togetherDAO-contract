// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {TogetherProxy} from "./TogetherProxy.sol";
import {TogetherInvest} from "./TogetherInvest.sol";

contract TogetherFactory {
    //======== Events ========

    event CreateProposalDeploy(
        address indexed partyProxy,  
        address indexed creator,
        address indexed nftContract,
        uint256 nftTokenId,
        address token,
        uint256 tokenAmount,
        uint256 secondsToTimeoutFoundraising,      
        uint256 secondsToTimeoutBuy,
        uint256 secondsToTimeoutSell,
        string name 
        
    );

    //======== Immutable storage =========

    address public immutable logic;   //逻辑合约
    address public immutable togetherDAO;  //手续费地址
    address public immutable weth;    

    //======== Mutable storage =========

    // PartyBid proxy => block number deployed at
    //  mapping(address => uint256) public deployedAt;   //???

    //======== Constructor =========

    constructor(
        address _togetherDAO,     //项目方address 
        address _weth,
        address _allowList
    ) {
        togetherDAO = _togetherDAO; 
      
        weth = _weth;
        // deploy logic contract
        TogetherInvest _logicContract = new TogetherInvest(
            _togetherDAO,           
            _weth,
            _allowList
        );
        // store logic contract address
        logic = address(_logicContract);
    }

    //======== Deploy function =========

    function createProposal(
        address _nftContract, 
        uint256 _nftTokenId,
        address _token,    
        uint256 _tokenAmount,
        uint256 _secondsToTimeoutFoundraising,
        uint256 _secondsToTimeoutBuy,    
        uint256 _secondsToTimeoutSell,     
        string memory _name       
    ) external returns (address togetherProxy) {
        bytes memory _initializationCalldata = abi.encodeWithSelector(
            TogetherInvest.initialize.selector,
            _nftContract,           
            _token,
            _tokenAmount,
            _secondsToTimeoutFoundraising,
            _secondsToTimeoutBuy,   
            _secondsToTimeoutSell,           
            _name            
        );
   
       togetherProxy = address(
            new TogetherProxy(logic, _initializationCalldata)
        );

        // deployedAt[partyBuyProxy] = block.number;

        emit CreateProposalDeploy(
            togetherProxy,
            msg.sender,
            _nftContract,         
            _token,
            _tokenAmount,
            _secondsToTimeoutFoundraising,
            _secondsToTimeoutBuy,    
            _secondsToTimeoutSell,           
            _name
        );
    }
}
