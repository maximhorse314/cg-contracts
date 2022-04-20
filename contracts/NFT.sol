//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract NFT is Ownable, ERC721URIStorage {
  // starting from 1
  uint256 public tokenId;
  // nft lending pool address
  address public lendingPool;

  event LogMint(address indexed account, uint256 tokenId, string uri);
  event LogTokenURISet(uint256 tokenId, string uri);
  event LogLendingPoolSet(address lendingPool);

  constructor() ERC721("Test NFT", "TNFT") {}

  function setLendingPool(address _lendingPool) external onlyOwner {
    lendingPool = _lendingPool;

    emit LogLendingPoolSet(_lendingPool);
  }

  function mint(string[] memory _uris) external onlyOwner {
    for(uint256 i = 0; i < _uris.length; i++) {
      uint256 newTokenId = tokenId + 1;
      address _lendingPool = lendingPool;
      super._mint(_lendingPool, newTokenId);
      super._setTokenURI(newTokenId, _uris[i]);
      tokenId = newTokenId;

      emit LogMint(_lendingPool, newTokenId, _uris[i]);
    }
  }
  
  function setTokenURI(
    uint256 _tokenId,
    string memory _uri
  ) external onlyOwner {
    super._setTokenURI(_tokenId, _uri);

    emit LogTokenURISet(_tokenId, _uri);
  }
}