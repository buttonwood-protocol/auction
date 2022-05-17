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
- `minPrice`: The lower bound for allowed prices
- `maxPrice`: The upper bound for allowed prices
- `tickWidth`: The spacing between allowed prices
- `endDate`: The UNIX timestamp (in seconds) at which the auction ends

Note that prices are denominated in `bid asset per askAsset`, adjusted for decimals. For example, if `askAsset` is USDC (6 decimals) and `bidAsset` is ETH (18 decimals), a price of `$2000 / ETH` would be represented as 2_000_000_000 (2000 USDC).

## Making bids and asks

A user who wants to participate in the auction can call the `bid` or `ask` function. These functions take as arguments the number of tokens that the user wishes to use to make their order, and the price. The auction contract takes control of their input tokens, and mints an equivalent number of `receipt` tokens. `Receipt` tokens are represented as an ERC1155 token, with the tokenId representing both the price and whether the order was a bid or ask.

## Settlement

After the auction's `endDate`, anyone can call the `settle()` function. During settlement the contract matches up bids and asks, determining which bids/asks have been "cleared", and the final `clearingPrice`. 


## Redemption

After settlement, users who hold receipt tokens can redeem them with the auction to get their owed tokens. 

If the user's order was not cleared, they will simply receive back their initial input tokens.

If the user's order was fully cleared, they will receive back the value of their order at the clearing price, along with any excess of their initially input tokens.

If the user's order was only partially cleared, they will receive the value of their order, prorated by the proportion of the cleared tokens at their price tick. They will also receive back any excess of their initially input tokens.
