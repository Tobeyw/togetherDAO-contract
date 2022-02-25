// SPDX-License-Identifier:UNLICENSED
pragma solidity ^0.8.0;
import { IERC20 } from "./interface/IERC20.sol";
import { SafeMath } from "./interface/SafeMath.sol";

contract togetherDao{
    uint256 internal constant CONST_NUMBER = 18446744073709551616;
    uint256 internal constant CONST_NUMBER_SQRT = 4294967296;


    address payable public  owner;
    uint256 public currentIndex;  
    mapping (uint256 => Proposal) public proposalList;
    mapping (uint256 => address[]) public investorList;  //投资人地址集合
  
    // IERC20 public acceptToken;
    struct Proposal{    
        address creator;
        address asset;
        uint256 createAt;
        address token;            //募资token        
        uint256 preAmount;        //需要募集金额  
        uint256 raisedAmount;     //已经募集金额  
        mapping (address => uint256) investor;  // 投资人及金额·列表  
        mapping (address => uint256) income;  // 投资人及金额·列表    
        uint256 foundraisingDDL;   //天   募资截止时间（上限？） 
        uint256 purchaseDDL;       //天   购买NFT截止时间     
        bool    state;            // 进行状态  true:进行中; false:结束
        
    }
   
    // event Sent(address from, address to, uint amount);
    
    constructor() {
       owner = payable(msg.sender) ;
       currentIndex =0;   
    }

    function CreateProposal(address _asset, address _token,uint256 _amount,uint256 _foundraisingDDL,uint256 _purchaseDDL) public {       
        //募资截止时间一定小于购买NFT截止时间
        require(_foundraisingDDL < _purchaseDDL,"Invalid parameter");
        require(_amount < 1e60,"Invalid parameter");
        currentIndex++;     
        Proposal storage proposal = proposalList[currentIndex];        
        require(proposal.createAt == 0,"Proposal existed");
        //创建提案
        proposal.creator = msg.sender;
        proposal.asset = _asset;
        proposal.token = _token;
        proposal.preAmount = _amount;
        proposal.createAt = block.timestamp;
        proposal.foundraisingDDL = _foundraisingDDL;
        proposal.purchaseDDL = _purchaseDDL; 
        proposal.state = true ;     

    }
     
    function Invest(uint256 _index, uint256 _amount) external {
        Proposal storage proposal = proposalList[_index];
        //判断募资是否结束        
        uint256 ddl =SafeMath.mul(proposal.foundraisingDDL,24*3600);
        require(SafeMath.add(proposal.createAt,ddl)> block.timestamp,"Expired") ; 
        //投资金额不能超过募资金额
        require(SafeMath.sub(proposal.preAmount,proposal.raisedAmount)>= _amount,"Invalid parameter"); 
        //将资金转到合约账户  
        require(IERC20(proposal.token).transfer(address(this),_amount),"Transfer failed"); 
        SafeMath.add(proposal.raisedAmount,_amount);  

        if(proposal.investor[msg.sender]==0){
            //投资人对同一个提案首次投资          
            investorList[_index].push(msg.sender);
        }
        proposal.investor[msg.sender] = SafeMath.add(proposal.investor[msg.sender],_amount);
      
    }

     //返还收益 提案完成
    function ReturnIncome(uint256 _index,uint256 _amount) external {
       require(owner==msg.sender,"No authorization");
       //TODO 计算平台收益和 提案人额外收益
       Proposal storage proposal = proposalList[_index];
       address[] memory investors = investorList[_index];
       for(uint256 i=0; i < investors.length; i++){
         address investor = investors[i];    
         uint256 income = SafeMath.div(SafeMath.mul(proposal.investor[investor], _amount),  proposal.raisedAmount);   
         require(income >0, "No income");   
         require(IERC20(proposal.token).transfer(investor,income),"ReturnIncome failed"); 
         proposal.income[investor] = income;
       }
       proposal.state = false;
    }

    //领取
    function Claim(uint256 _index) external {     
       Proposal storage proposal = proposalList[_index];
       //计算手续费
       uint256  proportion = Proportion(_index, msg.sender);
       uint256  fee =SafeMath.div(SafeMath.sqrt(proportion), CONST_NUMBER_SQRT);    //使用常量为了减小开根号的误差
       uint256  amount = SafeMath.sub(proposal.income[msg.sender] ,fee);      
       require(amount>0,"No income");
       require(IERC20(proposal.token).transferFrom(address(this),msg.sender,amount),"Claim failed");  
    }


     //计算投资占比 * 18446744073709551616
    function Proportion (uint256 _index,address investor) internal view returns (uint256 _proportion){     
        Proposal storage proposal = proposalList[_index]; 
        _proportion =  SafeMath.div(SafeMath.mul(proposal.investor[investor], CONST_NUMBER),  proposal.raisedAmount);       
       return  _proportion;
    }



}