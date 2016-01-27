local version = '1.0'
local author = 'shirsig'

local m = {}
bid_counter = m

local PAGE_SIZE = 50

function m.wait_for_page(k)
	local t0 = time()
	
	m.as_soon_as(function()
		if time() - t0 > 5 then -- we won't wait longer than 5 seconds
			return true
		end
		
		return m.bids_loaded and m.owner_data_complete()
		
	end, k)
end

function m.owner_data_complete()
	local n, _ = GetNumAuctionItems('bidder')
	for i = 1, n do
		if not ({GetAuctionItemInfo('bidder', i)})[12] then
			return false
		end
	end
	return true
end

function m.scan()
	m.load_page(function()
		
        local auctions_on_page, _ = GetNumAuctionItems('bidder')

		for i = 1, auctions_on_page do
			if GetAuctionItemInfo('bidder', i) then
				m.count = m.count + 1
			end			
		end
		
		if m.page + 1 < m.total_pages then
			m.page = m.page + 1
			return m.scan()
		else
			return m.k(m.count)
		end
		
    end)
end

function m.load_page(k)
	if m.page then
		m.wait_for_page(function()
			local _, total_count = GetNumAuctionItems('bidder')
			m.total_pages = math.ceil(total_count / PAGE_SIZE)
			return k()
		end)
		GetBidderAuctionItems(m.page)
	else
		return k()
	end
end

function m.count_bids(k)
	m.on_next_update(function()
		if m.ready then
			m.k = k
			m.count = 0
			m.page = 0
			m.scan()
		end
	end)
end

function m.on_event()
	if event == 'ADDON_LOADED' and string.lower(arg1) == "blizzard_auctionui" then
		local orig = PlaceAuctionBid
		function PlaceAuctionBid(type, index, bid)

			local buyout_price = ({GetAuctionItemInfo(type, index)})[9]
			if bid < buyout_price or buyout_price == 0 then
				m.count_bids(function(count)
					m.alert(count+1)
				end)
			end
			return orig(type, index, bid)
		end
	elseif event == 'AUCTION_HOUSE_SHOW' then
		m.ready = true
		m.count_bids(function(count)
			m.alert(count)
		end)
	elseif event == 'AUCTION_HOUSE_CLOSED' then
		m.ready = false
		m.state = nil
        m.bids_loaded = false
    elseif event == 'AUCTION_BIDDER_LIST_UPDATE' then
        m.bids_loaded = true
	end
end

function m.on_next_update(callback)
	return m.as_soon_as(function() return true end, callback)
end

function m.as_soon_as(p, callback)
	if not m.locked and m.ready then
		m.state = {
			p = p,
			callback = callback,
		}
	end
end

function m.on_update()
	if m.state and m.state.p() then
		local callback = m.state.callback
		m.state = nil
		return callback()
	end
end

function m.alert(count)
	local message = 'You have '..count..' active bids.'
	if DEFAULT_CHAT_FRAME then
		if count == 50 then
			SetCVar('MasterSoundEffects', 0)
			SetCVar('MasterSoundEffects', 1)
			PlaySoundFile('Interface\\AddOns\\bid_counter\\Event_wardrum_ogre.ogg', 'Master')
			PlaySoundFile('Interface\\AddOns\\bid_counter\\scourge_horn.ogg', 'Master')
			DEFAULT_CHAT_FRAME:AddMessage(strupper(message..' Any more may crash the game!'), 1, 0, 0)	
		elseif count > 45 then
			DEFAULT_CHAT_FRAME:AddMessage(message, 1, 0, 0)
		else
			DEFAULT_CHAT_FRAME:AddMessage(message, 1, 1, 0)
		end
	end
end

SLASH_BC1 = '/bc'
function SlashCmdList.BC()
	m.count_bids(function(count)
		m.alert(count)
	end)
end