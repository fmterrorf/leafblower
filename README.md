# Leafblower

Play Cards Against Humanity online with friends!

Head over to https://leafblower.fly.dev/ to test it out.


![Demo](./docs/mobile_demo.gif)


# Development

To run this project locally simply run

    mix deps.get
    mix phx.server

## Code organization

|   File    |   What it does |
| --------- | --------------- |
| [game_live](./lib/leafblower_web/controllers/game_live.ex) | This is what you see when you start playing the game |
| [game_statem](./lib/leafblower/game_statem.ex) | Handles the game state and logic |
| [deck](./lib/leafblower/deck.ex) | Handles all operations to the deck like drawing cards from it |
| [cards_against.json](./priv/cards_against.json) |  Stores all the cards used in the game. Taken from [JSON Against Humanity](https://github.com/crhallberg/json-against-humanity)

# FAQ

- Where did you get the card packs?  I got it from [JSON Against Humanity](https://github.com/crhallberg/json-against-humanity)