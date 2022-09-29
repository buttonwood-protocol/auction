# Price Representation

## What is a price?

There are a number of ways to represent prices in an auction. One important aspect to keep in mind is that prices are always fundamentally fractions between two currencies. In this case, it's the ratio of:
```
# of Bid Tokens (base units) : # of Ask Tokens (base units)
```

Thus, if you want to denote that 1 WETH is worth 1500 USDC, the fraction you want to represent is
```
 1500 USDC     1500 * (10**6) USDC-base-units
----------- = --------------------------------
 1 WETH         1 * (10**18) WETH-base-units
``` 

## How do we represent prices?

There are 4 approaches to representing this price:
- ERC20-Decimals
- 128-Method
- Fractions
- Common Denominator

### ERC20-Decimals
In this approach, price is denominated as:
```
# of Bid Base Units for 1 Ask Token
```
This approach is discouraged because the `decimals` property is not a required property of ERC20 tokens (rather from the metadata), and is also primarily for display purposes, not for calculations.

### 128-Method
In this approach, price is denominated as:
```
# of Bid Base Units for 2**128 Ask-Base-Units
```
This approach presents a standardized way to represent prices that is agnostic to the bid/ask assets. 
However, it is not very intuitive to read, and it constrains all prices to be in the format of the ratio `X : 2**128`.
- If you believe the bid-base-unit is worth 5x the ask-base-unit, you would represent this as `5 * 2**128`.
- However, there is no way to represent the bid-base-unit being worth 1/5 of the ask-base-unit.

### Fractions
This approach encodes the price as a fraction, where the numerator and denominator are both represented as `uint128`.
You can then write the price as the concatenation of these two bit strings for one `uint256` that can be converted to and from a tokenId.

This approach is much more flexible than the 128-Method, and is also more intuitive to read. However, given the variety of ways to represent a single fraction, it can cause issues when trying to add/subtract/multiply/divide prices.

If you don't enforce minPrice, maxPrice, and tickWidth to have the same denominators, then adding `3/5` to `2/7` requires many additional computations and higher gas costs.

### Common Denominator
This approach is the most flexible out of all the four approaches. It can be crafted in a way such that it's the most intuitive to read, and is the most straightforward to add/subtract/multiply/divide.

It's equivalent to the **ERC20-Decimals** approach, but with a common denominator set to `askAsset.decimals()`

It's equivalent to the **128-Method** approach, but with a common denominator set to `2**128`

It enforces simpler calculations than the **Fractions** approach, and does not restrict the numerator to fit within a `uint128`. 