local CANCELLING_TABLE_LAYOUT = {
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerParameters = { "name" },
    headerText = AUCTIONATOR_L_NAME,
    cellTemplate = "AuctionatorItemKeyCellTemplate",
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = AUCTIONATOR_L_QUANTITY,
    headerParameters = { "quantity" },
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { "quantity" },
    width = 70
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = AUCTIONATOR_L_UNIT_PRICE,
    headerParameters = { "price" },
    cellTemplate = "AuctionatorPriceCellTemplate",
    cellParameters = { "price" },
    width = 150,
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = AUCTIONATOR_L_TIME_LEFT_H,
    headerParameters = { "timeLeft" },
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { "timeLeft" },
    width = 120,
  },
}

local DATA_EVENTS = {
  "OWNED_AUCTIONS_UPDATED",
  "AUCTION_CANCELED"
}

AuctionatorCancellingDataProviderMixin = CreateFromMixins(DataProviderMixin, AuctionatorItemKeyLoadingMixin)

function AuctionatorCancellingDataProviderMixin:OnLoad()
  DataProviderMixin.OnLoad(self)
  AuctionatorItemKeyLoadingMixin.OnLoad(self)
  Auctionator.EventBus:Register(self, {Auctionator.Cancelling.Events.RequestCancel})

  self.waitingforCancellation = {}
  self.beenCancelled = {}

end

function AuctionatorCancellingDataProviderMixin:OnShow()
  C_AuctionHouse.QueryOwnedAuctions({})

  FrameUtil.RegisterFrameForEvents(self, DATA_EVENTS)
end

function AuctionatorCancellingDataProviderMixin:OnHide()
  FrameUtil.UnregisterFrameForEvents(self, DATA_EVENTS)
end

local COMPARATORS = {
  price = Auctionator.Utilities.NumberComparator,
  name = Auctionator.Utilities.StringComparator,
  quantity = Auctionator.Utilities.NumberComparator
}

function AuctionatorCancellingDataProviderMixin:Sort(fieldName, sortDirection)
  local comparator = COMPARATORS[fieldName](sortDirection, fieldName)

  table.sort(self.results, function(left, right)
    return comparator(left, right)
  end)

  self.onUpdate(self.results)
end

function AuctionatorCancellingDataProviderMixin:OnEvent(eventName, auctionID, ...)
  AuctionatorItemKeyLoadingMixin.OnEvent(self, event, ...)
  if eventName == "AUCTION_CANCELED" then
    table.insert(self.beenCancelled, auctionID)
    C_AuctionHouse.QueryOwnedAuctions({})

  elseif eventName == "OWNED_AUCTIONS_UPDATED" then
    self:Reset()
    self:PopulateAuctions()
  end
end

function AuctionatorCancellingDataProviderMixin:ReceiveEvent(eventName, eventData, ...)
  if eventName == Auctionator.Cancelling.Events.RequestCancel then
    table.insert(self.waitingforCancellation, eventData)
  end
end

function AuctionatorCancellingDataProviderMixin:IsValidAuction(auctionInfo)
  return
    auctionInfo.status == 0 and
    Auctionator.Utilities.ArrayIndex(self.beenCancelled, auctionInfo.auctionID) == nil
end

function AuctionatorCancellingDataProviderMixin:PopulateAuctions()
  local results = {}

  local index
  for index = 1, C_AuctionHouse.GetNumOwnedAuctions() do
    local info = C_AuctionHouse.GetOwnedAuctionInfo(index)

    --Only look at unsold and uncancelled (yet) auctions
    if self:IsValidAuction(info) then
      table.insert(results, {
        id = info.auctionID,
        quantity = info.quantity,
        price = info.buyoutAmount or info.bidAmount,
        itemKey = info.itemKey,
        timeLeft = math.ceil(info.timeLeftSeconds/60/60),
        cancelled = (Auctionator.Utilities.ArrayIndex(self.waitingforCancellation, info.auctionID) ~= nil)
      })
    end
  end
  self:AppendEntries(results, true)
end

function AuctionatorCancellingDataProviderMixin:UniqueKey(entry)
  return tostring(entry.id)
end

function AuctionatorCancellingDataProviderMixin:GetTableLayout()
  return CANCELLING_TABLE_LAYOUT
end

function AuctionatorCancellingDataProviderMixin:GetRowTemplate()
  return "AuctionatorCancellingListResultsRowTemplate"
end