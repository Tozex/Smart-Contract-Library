// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ICrypto4AllNFT is IERC721 {
    function isApproved(uint256 _tokenId, address _operator) external view returns (bool);
    function setPrimarySalePrice(uint256 _tokenId, uint256 _salePrice) external;
    function postCreators(uint256 _tokenId) external view returns (address);
    function exists(uint256 _tokenId) external view returns (bool);
    function mint(address _beneficiary, string calldata _tokenUri, address _designer) external returns (uint256);
    function burn(uint256 _tokenId) external;
}
