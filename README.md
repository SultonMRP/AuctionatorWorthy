# AuctionatorWorthy

Auctionator and Auctionworthy together for WoW 3.3.5a on AzerothCore (Aethro).

Install the release zip by extracting it into `Interface\AddOns`. You should end up with both folders side by side:

- `Interface\AddOns\Auctionator`
- `Interface\AddOns\Auctionworthy`

Auctionworthy needs Auctionator for prices. After installing, open the auction house and run a full scan once. The scan walks the house in pages of 50, which is what AzerothCore returns.

`/auctionworthy` or `/worthy` opens the tooltip options. Hold Shift for full-stack numbers.

Undercut is a **read-only** copy of Auctionator's `AUCTIONATOR_SAVEDVARS` brackets (the Undercutting window: over 500g, 100g, 20g, and so on). Worthy never writes those saved vars. Posting prices use the same round-down as Auctionator's sell tab.

`/worthy refresh` re-reads those brackets without a `/reload`. Closing Auctionator's options window does the same silently.

Auctionator is based on Zirco's Auctionator 2.6.8. The full scan in this copy does not use the client's get-all query. Auctionworthy is by spzilyk.
