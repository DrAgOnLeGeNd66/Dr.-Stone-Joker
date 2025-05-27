--- STEAMODDED HEADER
--- MOD_NAME: Dr. Stone Joker
--- MOD_ID: DrStoneJoker
--- MOD_AUTHOR: [Tetsu]
--- MOD_DESCRIPTION: A joker that gives X2 Mult and an additional X0.2 for every stone card in your deck
--- BADGE_COLOUR: 8B4513
--- PREFIX: dr_stone
--- VERSION: 1.0.0

----------------------------------------------
------------MOD CODE -------------------------

-- Initialize the mod
local mod_id = "dr_stone"

-- Function to count stone cards in deck
local function count_stone_cards()
    local stone_count = 0
    
    -- Check all areas where cards might be stored
    local areas_to_check = {}
    if G.deck and G.deck.cards then
        table.insert(areas_to_check, G.deck.cards)
    end
    if G.hand and G.hand.cards then
        table.insert(areas_to_check, G.hand.cards)
    end
    if G.play and G.play.cards then
        table.insert(areas_to_check, G.play.cards)
    end
    if G.discard and G.discard.cards then
        table.insert(areas_to_check, G.discard.cards)
    end
    
    for _, card_area in ipairs(areas_to_check) do
        for i = 1, #card_area do
            local card = card_area[i]
            -- Check multiple ways a card can be identified as stone
            if card and card.config and card.config.center then
                if card.config.center.key == 'm_stone' or 
                   (card.config.center.name and string.find(card.config.center.name, 'Stone')) then
                    stone_count = stone_count + 1
                end
            end
        end
    end
    
    return stone_count
end

-- Function to calculate current multiplier
local function calculate_dr_stone_mult()
    local base_mult = 2.0
    local stone_count = count_stone_cards()
    local bonus_mult = stone_count * 0.2
    local total_mult = base_mult + bonus_mult
    -- Ensure it never goes below base multiplier
    return math.max(total_mult, base_mult)
end

-- Create the Dr. Stone joker
SMODS.Joker{
    key = 'dr_stone',
    loc_txt = {
        name = 'Dr. Stone',
        text = {
            '{X:mult,C:white}X2{} Mult, gives an',
            'additional {X:mult,C:white}X0.2{} Mult for',
            'every {C:attention}Stone Card{} in Deck',
            '{C:green}Current: {C:red}X#1#{}'
        }
    },
    config = {
        extra = {
            x_mult = 2.0,
            stone_bonus = 0.2
        }
    },
    rarity = 2, -- Uncommon rarity
    cost = 6,
    blueprint_compat = true,
    eternal_compat = true,
    perishable_compat = true,
    pos = {x = 0, y = 0},
    atlas = 'j_dr_stone',
    
    -- Function called when calculating multipliers
    calculate = function(self, card, context)
        if context.joker_main then
            local current_mult = calculate_dr_stone_mult()
            card.ability.extra.current_mult = current_mult -- Store for display
            return {
                message = localize{type='variable',key='a_xmult',vars={current_mult}},
                Xmult_mod = current_mult,
                colour = G.C.MULT
            }
        end
    end,
    
    -- Function to update the card's display text
    loc_vars = function(self, info_queue, center)
        local current_mult = calculate_dr_stone_mult()
        return {vars = {string.format("%.1f", current_mult)}}
    end,
    
    -- Function called when the joker is added to check for stone cards
    add_to_deck = function(self, card, from_debuff)
        -- Update the card display when added
        card.ability.extra.current_mult = calculate_dr_stone_mult()
    end,
    
    -- Function called when cards are added to deck
    other_joker = function(self, card, other_card, context)
        if context.blueprint and context.blueprint == card then
            if context.joker_main then
                local current_mult = calculate_dr_stone_mult()
                return {
                    message = localize{type='variable',key='a_xmult',vars={current_mult}},
                    Xmult_mod = current_mult,
                    colour = G.C.MULT
                }
            end
        end
    end
}

-- Create atlas for the joker sprite
SMODS.Atlas{
    key = 'j_dr_stone',
    path = 'dr_stone.png',
    px = 71,
    py = 95
}

-- Function to update all Dr. Stone jokers
local function update_dr_stone_jokers()
    if G.jokers then
        for i = 1, #G.jokers.cards do
            local joker = G.jokers.cards[i]
            if joker.config and joker.config.center and joker.config.center.key == 'j_dr_stone_dr_stone' then
                local old_mult = joker.ability.extra.current_mult or 2.0
                local new_mult = calculate_dr_stone_mult()
                
                -- Show popup for both increases and decreases (but not when staying the same)
                if new_mult ~= old_mult then
                    local color = new_mult > old_mult and G.C.RED or G.C.BLUE
                    
                    card_eval_status_text(joker, 'extra', nil, nil, nil, {
                        message = localize{type='variable',key='a_xmult',vars={new_mult}},
                        colour = color,
                        card = joker
                    })
                    
                    -- Trigger a visual update
                    if joker.children and joker.children.center then
                        joker.children.center:juice_up()
                    end
                end
                
                joker.ability.extra.current_mult = new_mult
            end
        end
    end
end

-- Hook into multiple events to catch stone card changes
local set_ability_ref = Card.set_ability
function Card:set_ability(center, initial, delay_sprites)
    local ret = set_ability_ref(self, center, initial, delay_sprites)
    
    -- Check if this card was just turned into a stone card
    if center and center.key == 'm_stone' then
        -- Update all Dr. Stone jokers immediately and with delay
        update_dr_stone_jokers()
        G.E_MANAGER:add_event(Event({
            trigger = 'after',
            delay = 0.2,
            func = function()
                update_dr_stone_jokers()
                return true
            end
        }))
    end
    
    return ret
end

-- Also hook into card use events for tarot cards
local use_consumeable_ref = Card.use_consumeable
function Card:use_consumeable(area, copier)
    local ret = use_consumeable_ref(self, area, copier)
    
    -- After any consumeable is used, check if stone cards were created
    G.E_MANAGER:add_event(Event({
        trigger = 'after',
        delay = 0.3,
        func = function()
            update_dr_stone_jokers()
            return true
        end
    }))
    
    return ret
end

-- Hook into card removal to update Dr. Stone jokers when stone cards are removed
local remove_from_deck_ref = Card.remove_from_deck
function Card:remove_from_deck(from_debuff)
    local was_stone = false
    if self.config and self.config.center and self.config.center.key == 'm_stone' then
        was_stone = true
    end
    
    local ret = remove_from_deck_ref(self, from_debuff)
    
    -- If a stone card was removed, update all Dr. Stone jokers
    if was_stone then
        G.E_MANAGER:add_event(Event({
            trigger = 'after',
            delay = 0.1,
            func = function()
                update_dr_stone_jokers()
                return true
            end
        }))
    end
    
    return ret
end

----------------------------------------------
------------MOD CODE END----------------------