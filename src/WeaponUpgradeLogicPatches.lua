function OpenWeaponUpgradeScreen( args )

	AltAspectRatioFramesShow()

	local screen = DeepCopyTable( ScreenData.WeaponUpgradeScreen )
	
	HideCombatUI( screen.Name )
	wait( 0.1 )
	OnScreenOpened( screen )
	CreateScreenFromData( screen, screen.ComponentData )
	screen.ItemStartX = screen.ItemStartX + ScreenCenterNativeOffsetX
	screen.ItemStartY = screen.ItemStartY + ScreenCenterNativeOffsetY

	local weaponName = args.WeaponName
	local weaponData = WeaponData[weaponName]
	
	local components = screen.Components

	ModifyTextBox({ Id = components.TitleText.Id, Text = weaponName.."_Aspects" })
	ModifyTextBox({ Id = components.TitleFlavorText.Id, Text = weaponName.."_Aspects", UseDescription = true, })

	local weaponKills = GameState.WeaponKills[weaponName] or 0
	for i, linkedWeaponName in ipairs( WeaponSets.HeroWeaponSets[weaponName] ) do
		weaponKills = weaponKills + (GameState.WeaponKills[linkedWeaponName] or 0)
	end
	if weaponKills == 0 then
		weaponKills = nil
	end
	ModifyTextBox({ Id = components.KillsValue.Id, Text = weaponKills })

	local clearStats = WeaponUpgradeScreenGetStats( screen, weaponName )
	if clearStats ~= nil then
		if clearStats.ClearCount ~= nil then
			ModifyTextBox({ Id = components.ClearsValue.Id, Text = clearStats.ClearCount })
		end
		if clearStats.FastestTimeUnderworld ~= nil then
			ModifyTextBox({ Id = components.UnderworldClearTimeRecordValue.Id, Text = GetTimerString( clearStats.FastestTimeUnderworld, 2 ) })
		end
		if clearStats.FastestTimeSurface ~= nil then
			ModifyTextBox({ Id = components.SurfaceClearTimeRecordValue.Id, Text = GetTimerString( clearStats.FastestTimeSurface, 2 ) })
		end
		if clearStats.HighestShrinePointsUnderworld ~= nil then
			ModifyTextBox({ Id = components.UnderworldShrinePointRecordValue.Id, Text = clearStats.HighestShrinePointsUnderworld })
		end
		if clearStats.HighestShrinePointsSurface ~= nil then
			ModifyTextBox({ Id = components.SurfaceShrinePointRecordValue.Id, Text = clearStats.HighestShrinePointsSurface })
		end
	end

	PlaySound({ Name = "/SFX/Menu Sounds/GeneralWhooshMENULoud" })

	thread( PlayVoiceLines, GlobalVoiceLines.OpenedWeaponUpgradeMenuVoiceLines, true, CurrentRun.Hero, args )

	local freeUnlockName = screen.FreeUnlocks[weaponName]
	if freeUnlockName ~= nil then
		GameState.WeaponsUnlocked[freeUnlockName] = true
	end

	screen.TraitList = {}
	screen.WeaponName = weaponName

	local itemIndex = 0
	for i, itemName in ipairs( screen.DisplayOrder[weaponName] ) do
		local rawTraitData = TraitData[itemName]
		if rawTraitData ~= nil and GameState.WeaponsUnlocked[itemName] then
			itemIndex = itemIndex + 1

			local traitData = GetProcessedTraitData({ Unit = CurrentRun.Hero, TraitName = itemName, Rarity = GetRarityKey( GetWeaponUpgradeLevel( itemName ), TraitRarityData.WeaponRarityUpgradeOrder ) })
			SetTraitTextData( traitData )
			table.insert(screen.TraitList, traitData)
		end
	end

	CreateAspectButtons(screen)

	local equipped = UpdateWeaponUpgradeButtons( screen )
	while not equipped and equipped ~= nil do
		equipped = WeaponUpgradeScreenNext(screen, screen.Components.PageDown)
	end

	screen.KeepOpen = true
	screen.CanClose = true
	HandleScreenInput( screen )
end


function CreateAspectButtons( screen )
	local components = screen.Components
	local weaponName = screen.WeaponName
	local weaponData = WeaponData[weaponName]
	for itemIndex = screen.StartingIndex, math.min(screen.StartingIndex + screen.NumPerPage - 1, #screen.TraitList), 1 do
		local traitData = screen.TraitList[itemIndex]
		local rawTraitData = TraitData[traitData.Name]
		local purchaseButtonKey = "PurchaseButton"..itemIndex
		local slotData = DeepCopyTable( screen.ButtonSlotData )
		local locationX = screen.ItemStartX
		local locationY = screen.ItemStartY + ( (itemIndex - screen.StartingIndex) * screen.ItemSpacingY )
		slotData.X = locationX
		slotData.Y = locationY
		slotData.Alpha = 0.0
		slotData.AlphaTarget = 1.0
		slotData.AlphaTargetDuration = 0.4
		slotData.Animation = rawTraitData.InfoBackingAnimation

		local button = CreateComponentFromData( screen, slotData )
		components[purchaseButtonKey] = button
		button.OnPressedFunctionName = "HandleWeaponUpgradeSelection"
		button.OnMouseOverFunctionName = "MouseOverWeaponUpgrade"
		button.OnMouseOffFunctionName = "MouseOffWeaponUpgrade"
		button.Screen = screen
		button.WeaponName = weaponName
		button.TraitData = traitData 
		SetInteractProperty({ DestinationId = button.Id, Property = "TooltipOffsetX", Value = screen.TooltipOffsetX })
		AttachLua({ Id = button.Id, Table = button })
		local highlight = ShallowCopyTable( screen.Highlight )
		highlight.X = button.X
		highlight.Y = button.Y
		components[purchaseButtonKey.."Highlight"] = CreateScreenComponent( highlight )
		button.Highlight = components[purchaseButtonKey.."Highlight"]
		
		-- Hidden description for tooltip
		CreateTextBox({ Id = components[purchaseButtonKey].Id,
			Text = traitData.Name,
			UseDescription = true,
			Color = Color.Transparent,
			LuaKey = "TooltipData",
			LuaValue = traitData,
		})
		if traitData.StatLines then
			CreateTextBox({ Id = components[purchaseButtonKey].Id,
				Text = traitData.StatLines[1],
				Color = Color.Transparent,
				LuaKey = "TooltipData",
				LuaValue = traitData,
			})
		end

		local equippedIcon = CreateScreenComponent( screen.EquippedIcon )
		components[purchaseButtonKey.."EquippedIcon"] = equippedIcon
		button.EquippedIcon = equippedIcon
		Attach({ Id = equippedIcon.Id, DestinationId = components[purchaseButtonKey].Id, OffsetX = screen.EquippedIcon.OffsetX, OffsetY = screen.EquippedIcon.OffsetY })

		local childrenNames = GetAllKeys( slotData.Children )
		for _, name in pairs( childrenNames ) do
			if Contains( slotData.ChildrenOrder, name ) then
				slotData.ChildrenOrder[GetKey(slotData.ChildrenOrder, name)] = name..itemIndex
			end
			slotData.Children[name..itemIndex] = slotData.Children[name]
			slotData.Children[name] = nil
		end

		AttachChildrenFromData( screen, components[purchaseButtonKey], slotData, screen )
	
		if traitData.Icon ~= nil then
			SetAnimation({ Name = traitData.Icon, DestinationId = components["InfoBoxIcon"..itemIndex].Id })
			SetAlpha({ Id = components["InfoBoxIcon"..itemIndex].Id, Fraction = 1.0, Duration = 0.2 })
			SetAlpha({ Id = components["InfoBoxFrame"..itemIndex].Id, Fraction = 1.0, Duration = 0.2 })
		end

		local rarityColor = Color.White
		if traitData.Rarity then
			rarityColor = Color["BoonPatch"..traitData.Rarity]
			SetAnimation({ DestinationId = components["InfoBoxFrame"..itemIndex].Id, Name = "Frame_Boon_Menu_"..traitData.Rarity })
		end
		ModifyTextBox({ Id = components["InfoBoxName"..itemIndex].Id,
			Text = traitData.Title,
			LuaKey = "TooltipData",
			LuaValue = traitData,
			Color = rarityColor,
		})
		local rarityLevel = GetRarityValue( traitData.Rarity )
		ModifyTextBox({ Id = components["InfoBoxRarity"..itemIndex].Id,
			Text = TraitRarityData.AspectRarityText[rarityLevel],
			Color = rarityColor,
		})

		ModifyTextBox({ Id = components["InfoBoxDescription"..itemIndex].Id,
			Text = traitData.Name,
			UseDescription = true,
			LuaKey = "TooltipData",
			LuaValue = traitData,
		})

		local statLine = traitData.StatLines[1]
		ModifyTextBox({ Id = components["InfoBoxStatLineLeft"..itemIndex].Id, AppendToId = components["InfoBoxDescription"..itemIndex].Id, Text = statLine, LuaKey = "TooltipData", LuaValue = traitData, FadeTarget = 1.0 })
		ModifyTextBox({ Id = components["InfoBoxStatLineRight"..itemIndex].Id, AppendToId = components["InfoBoxDescription"..itemIndex].Id, Text = statLine, UseDescription = true, LuaKey = "TooltipData", LuaValue = traitData, FadeTarget = 1.0 })

		ModifyTextBox({ Id = components["InfoBoxFlavor"..itemIndex].Id,
			Text = traitData.FlavorText,
		})

		if HeroHasTrait( traitData.Name ) then
			SetAnimation({ Name = weaponData.UpgradeScreenKitAnimation, GrannyModel = traitData.WeaponKitGrannyModel, DestinationId = components.WeaponImage.Id })
			screen.WeaponUpgradeScreenKitAnimationApplied = true
			TeleportCursor({ OffsetX = ScreenCenterX + 40, OffsetY = 20 + (itemIndex - screen.StartingIndex + 1) * 220, ForceUseCheck = true })
		end
	end
	if not screen.WeaponUpgradeScreenKitAnimationApplied then
		local traitData = TraitData[screen.DisplayOrder[weaponName][1]]
		SetAnimation({ Name = weaponData.UpgradeScreenKitAnimation, GrannyModel = traitData.WeaponKitGrannyModel, DestinationId = components.WeaponImage.Id })
	end
end

function ClearAspectButtons( screen )
	local components = screen.Components
	local ids = {}
	local slot_prefix = {
		"InfoBoxDescription",
		"InfoBoxIcon",
		"InfoBoxFrame",
		"InfoBoxName",
		"InfoBoxRarity",
		"InfoBoxStatLineLeft",
		"InfoBoxStatLineRight",
		"InfoBoxFlavor",
	}
	local purchase_suffix = {
		"Highlight",
		"EquippedIcon",
		"",
	}
	for itemIndex = screen.StartingIndex, math.min(screen.StartingIndex + screen.NumPerPage - 1, #screen.TraitList) do
		for index, value in ipairs(slot_prefix) do
			table.insert(ids, components[value..itemIndex].Id)
		end
		for index, value in ipairs(purchase_suffix) do
			local purchaseButtonKey = "PurchaseButton"..itemIndex
			table.insert(ids, components[purchaseButtonKey..value].Id)
		end
	end
	Destroy({Ids = ids})
end

function WeaponUpgradeScreenPrevious( screen, button )
	if not screen.TraitList[screen.StartingIndex - screen.NumPerPage] then
		return
	end
	local components = screen.Components
	ClearAspectButtons(screen)
	screen.StartingIndex = screen.StartingIndex - screen.NumPerPage
	CreateAspectButtons(screen)
	local equipped = UpdateWeaponUpgradeButtons(screen)
	TeleportCursor({ DestinationId = screen.Components["PurchaseButton"..(screen.StartingIndex + screen.NumPerPage - 1)].Id, ForceUseCheck = true })
	GenericScrollPresentation( screen, button )
	return equipped
end

function WeaponUpgradeScreenNext( screen, button )
	if not screen.TraitList[screen.StartingIndex + screen.NumPerPage] then
		return
	end
	local components = screen.Components
	ClearAspectButtons(screen)
	screen.StartingIndex = screen.StartingIndex + screen.NumPerPage
	CreateAspectButtons(screen)
	local equipped = UpdateWeaponUpgradeButtons(screen)
	TeleportCursor({ DestinationId = screen.Components["PurchaseButton"..(screen.StartingIndex)].Id, ForceUseCheck = true })
	GenericScrollPresentation( screen, button )
	return equipped
end