//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract LendingPool is Ownable, IERC721Receiver, ReentrancyGuard {
  // NFT contract address
  address public immutable nft;
  // maximum loan period
  uint256 public constant MAX_LOAN_DURATION = 30 days;
  // interest rate in basis points, less than 1000
  uint16 public interestRate = 500;

  struct Loan {
    address renter;
    uint256 rentTime;
  }
  // nft id => value in ether
  mapping(uint256 => uint256) public nftValues;
  // nft id => loan info
  mapping(uint256 => Loan) public loans;

  event LogEthReceive(address indexed account, uint256 amount);
  event LogNFTValueSet(uint256 tokenId, uint256 amount);
  event LogRepay(address indexed account, uint256 tokenId);
  event LogEthSweep(address indexed receiver, uint256 amount);
  event LogCollateralClaim(uint256 tokenId);
  event LogInterestRateSet(uint16 rate);

  constructor(address _nft) {
    nft = _nft;
  }

  receive() external payable {
    emit LogEthReceive(msg.sender, msg.value);
  }

  function onERC721Received(
    address,
    address,
    uint256,
    bytes calldata
  ) external override returns (bytes4) {
    return this.onERC721Received.selector;
  } 

  /**
   * @dev Set nft values
   * Accessible only by owner
   */
  function setNFTValues(
    uint256[] memory _tokenIds,
    uint256[] memory _values
  ) external onlyOwner {
    require(_tokenIds.length == _values.length, "array length mismatch");
    for(uint256 i = 0; i < _tokenIds.length; i++) {
      nftValues[_tokenIds[i]] = _values[i];

      emit LogNFTValueSet(_tokenIds[i], _values[i]);
    }
  }

  /**
   * @dev Set interest rate in basis points
   * Accessible only by owner
   */
  function setInterestRate(uint16 _rate) external onlyOwner {
    require(_rate <= 1000, "invalid interest rate");
    interestRate = _rate;

    emit LogInterestRateSet(_rate);
  }

  /**
   * @dev Get nft loan from the pool
   * If nft ownership did change or loan expired, last collateral is claimed
   * and new loan is processed
   */
  function borrowNFT(uint256 _tokenId) external payable nonReentrant {
    require(IERC721(nft).balanceOf(msg.sender) == 0, "caller already borrowed");

    // check loan status
    address nftOwner = IERC721(nft).ownerOf(_tokenId);
    Loan memory loan = loans[_tokenId];
    if (nftOwner != address(this) && (nftOwner != loan.renter || loan.rentTime + MAX_LOAN_DURATION <= block.timestamp)) 
      _claimCollateral(_tokenId);

    uint256 preBal = address(this).balance;
    uint256 value = nftValues[_tokenId];
    require(msg.value >= value, "insufficient funds");
    loans[_tokenId].renter = msg.sender;
    loans[_tokenId].rentTime = block.timestamp;
    uint256 change = msg.value - value;
    // return change
    if (change > 0) {
      payable(msg.sender).transfer(change);
    }
    IERC721(nft).safeTransferFrom(address(this), msg.sender, _tokenId);
    uint256 bal = address(this).balance;
    // safety check
    require(bal >= preBal, "invalid loan");
  }

  function repayLoan(uint256 _tokenId) external payable nonReentrant {
    Loan memory loan = loans[_tokenId];

    // check loan status
    if (loan.renter != msg.sender || IERC721(nft).ownerOf(_tokenId) != msg.sender || loan.rentTime + MAX_LOAN_DURATION <= block.timestamp) {
      _claimCollateral(_tokenId);

      revert("invalid loan");
    }

    uint256 value = nftValues[_tokenId];
    uint256 interest = value * interestRate / 10000;
    require(msg.value >= interest, "insufficient funds");
    payable(msg.sender).transfer(msg.value - interest + value);
    IERC721(nft).safeTransferFrom(msg.sender, address(this), _tokenId);

    emit LogRepay(msg.sender, _tokenId);
  }

  function sweepEth(
    address _receiver,
    uint256 _amount
  ) external payable onlyOwner {
    require(_receiver != address(0), "receiver address invalid");
    require(address(this).balance >= _amount, "insufficient funds");
    payable(_receiver).transfer(_amount);

    emit LogEthSweep(_receiver, _amount);
  }

  function claimCollateral(uint256 _tokenId) external onlyOwner {
    address nftOwner = IERC721(nft).ownerOf(_tokenId);
    Loan memory loan = loans[_tokenId];
    require(loan.renter != nftOwner || loan.rentTime + MAX_LOAN_DURATION <= block.timestamp, "good loan");
    _claimCollateral(_tokenId);
  }

  function _claimCollateral(uint256 _tokenId) private {
    delete loans[_tokenId];

    emit LogCollateralClaim(_tokenId);
  }
}
