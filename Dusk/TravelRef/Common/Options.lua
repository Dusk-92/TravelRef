-- Plugin manager Options tab.

function Options_Box(OP,Ypos,text)
	local Box = Turbine.UI.Lotro.CheckBox()
	Box:SetParent( OP )
	Box:SetPosition( 10, Ypos )
	Box:SetSize( 220, 22 )
	Box:SetText( text )
	return Box
end

function Options_sBar(OP,scale,Window)
	local sBar = Turbine.UI.Lotro.ScrollBar()
	sBar:SetParent( OP )
	sBar:SetPosition( 10, 25 )
	sBar:SetSize( 220, 14 )
	sBar:SetMinimum( 50 )
	sBar:SetMaximum( 200 )
	sBar:SetSmallChange( 10 )
	sBar:SetLargeChange( 50 )
	sBar:SetValue( scale*100 )
	sBar.lbl = Turbine.UI.Label()
	sBar.lbl:SetParent( OP )
	sBar.lbl:SetPosition( 30,10 )
	sBar.lbl:SetSize( 150,15 )
	sBar.lbl:SetText( string.format("Échelle de la fenêtre : %.2f", scale) )
	if type(TR_ApplyScale)=="function" then TR_ApplyScale(scale)
	else Window:SetScale(scale) end
	return sBar
end

local YP = 10

function Options_Init(print,Settings,Window,Fname,Window2)
	local OP = Turbine.UI.Control()
	OP:SetBackColor( Turbine.UI.Color(0.0, 0.0, 0.0) )
	OP:SetSize( 240, 260 )
	plugin.GetOptionsPanel = function( self ) return OP end
	if not Window then return OP end
	if not Settings then Settings = {} end

	if Settings.scale and Window.SetScale then
		YP = 45
		local wScale = Options_sBar(OP,Settings.scale,Window)
		wScale.ValueChanged = function(sender, args)
			local scale = wScale:GetValue()/100
			Settings.scale = scale
			wScale.lbl:SetText( string.format("Échelle de la fenêtre : %.2f", scale) )
			if type(TR_ApplyScale)=="function" then
				TR_ApplyScale(scale)
			else
				Window:SetScale(scale)
				if Window2 then Window2:SetScale(scale) end
			end
		end
	end

	local autoBox = Options_Box(OP,YP," Ouvrir automatiquement")
	if Settings.pos1 or Settings.auto then
		if Settings.auto then 
			Window:SetVisible( true )
			autoBox:SetChecked( true )
		end
		if type(Settings.auto)=="table" and not Settings.pos1 then
			Settings.pos1 = Settings.auto -- patch for old version
		end
	end
	autoBox.CheckedChanged = function( sender, args )
		if not Settings then Settings = {} end
		Settings.auto = sender:IsChecked()
		if Settings.auto then
			local x,y = Window:GetPosition()
			Settings.auto = { x=x, y=y }
			Settings.pos1 = { x=x, y=y }
			if Window2 then
				x,y = Window2:GetPosition()
				Settings.pos2 = { x=x, y=y }
			end
			print("Position de la fenêtre enregistrée.")
		end
		print((Settings.auto and "Activé" or "Désactivé").." : ouverture automatique.")
		if Fname then
			Dusk.TravelRef.Common.PluginDataSave(Turbine.DataScope.Server,Fname,Settings)
			print("Paramètres enregistrés.")
		end
	end
	if Window2==false then return OP,YP+20 end -- supress esc?
	
	OP.noEsc = Options_Box(OP,YP+20," Ignorer la touche Échap")
	if Settings and Settings.esc then OP.noEsc:SetChecked( true ) end
	OP.noEsc.CheckedChanged = function( sender, args )
		if not Settings then Settings = {} end
		Settings.esc = sender:IsChecked()
		print((Settings.esc and "Activé" or "Désactivé").." : ignorer la touche Échap.")
		if Fname then
			Dusk.TravelRef.Common.PluginDataSave(Turbine.DataScope.Server,Fname,Settings)
			print("Paramètres enregistrés.")
		end
	end
	return OP,YP+40
end
