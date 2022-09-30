# Buttonwood Auction Box

Implementation for the Buttonwood Auction Box. This is a time-boxed price-discovery process for newly created assets, especially useful for derivatives such as bonds.


Buttonwood Auction Box is simple a way for large numbers of buyers and large numbers of sellers to 
figure out a fair price to transact. The benefit of this approach is that for a brand new token, it allows a lot 
of “liquidity” to exist from the start, without the need of a market maker or liquidity provider. The auction is a 
double-auction, modified to make sense in a high-latency, high-transaction cost, non-private environment.


# How it Works

## Setup

The auction is instantiated with the following parameters:
- `bidAsset`: The asset which is being used to purchase
- `askAsset`: The asset which is being purchased
- `minPrice`: The numerator of the lower bound for allowed prices
- `maxPrice`: The numerator of the upper bound for allowed prices
- `tickWidth`: The numerator of the spacing between allowed prices.
    - Must evenly divide the range between `minPrice` and `maxPrice` by `NUM_TICKS = 100`.
- `priceDenominator`: The common denominator for all the underlying prices
- `endDate`: The UNIX timestamp (in seconds) at which the auction ends

Note that prices are denominated in `bid asset per ask Asset`, adjusted for granularity.
All prices are represented as fractions, with a common denominator being `priceDenominator`:
- The underlying minimum price is `minPrice/priceDenominator`
- The underlying maximum price is `maxPrice/priceDenominator`
- The underlying tick width is `tickWidth/priceDenominator`.

For example, if `askAsset` is USDC (6 decimals) and `bidAsset` is WETH (18 decimals), a price of `$2000 / ETH` can be represented in a number of ways.
- The clearest representation is `2000 * (10**6)` USDC base units for each 1 WETH (or `10**18` WETH base units)
    - Price: `(2000 * (10**6))`, PriceDenominator: `(10**18)`
- The above fraction could also be adjusted for more granularity or less by multiplying/dividing the denominator by powers of 10. The below fractions are equivalent price representations:
    - Price: `2`, PriceDenominator: `(10**9)` (if you want price to move in larger increments)
    - Price: `(2000 * (10**9))`, PriceDenominator: `(10**21)` (if you want price to move in smaller increments)

There's a trade-off with the granularity of the price.
- The larger you make `priceDenominator`, the larger scale you'll need to denote prices. This reduces your ability to trade since
    - Converting between `bidTokens` to `askTokens` requires multiplying by `priceDenominator` and dividing by `price`. Hence, if you make `bidTokens * priceDenominator` too large, your math will overflow and revert.
    - Converting between `askTokens` to `bidTokens` requires multiplying by `price` and dividing by `priceDenominator`. Hence, if you make `askTokens * price` too large, your math will overflow and revert.
 
One recommendation is to keep `priceDenominator` as a power of 10 for simple UI integrations. 

## Making bids and asks

A user who wants to participate in the auction can call the `bid` or `ask` function. These functions take as arguments the number of tokens that the user wishes to use to make their order, and the price. The auction contract takes control of their input tokens, and mints an equivalent number of `receipt` tokens. `Receipt` tokens are represented as an ERC1155 token, with the tokenId representing both the price and whether the order was a bid or ask.

## Settlement

After the auction's `endDate`, anyone can call the `settle()` function. During settlement the contract matches up bids and asks, determining which bids/asks have been "cleared", and the final `clearingPrice`. 


## Redemption

After settlement, users who hold receipt tokens can redeem them with the auction to get their owed tokens. 

If the user's order was not cleared, they will simply receive back their initial input tokens.

If the user's order was fully cleared, they will receive back the value of their order at the clearing price, along with any excess of their initially input tokens.

If the user's order was only partially cleared, they will receive the value of their order, prorated by the proportion of the cleared tokens at their price tick. They will also receive back any excess of their initially input tokens.
