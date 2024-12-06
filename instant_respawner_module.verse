instant_respawners_module<public> := module:
    using { device_settings_utils }
    using { /Fortnite.com/Characters }
    using { /Fortnite.com/Devices }
    using { /Fortnite.com/FortPlayerUtilities }
    using { /Fortnite.com/Game }
    using { /Fortnite.com/Playspaces }
    using { /Fortnite.com/Teams }
    using { instant_respawners }
    using { /UnrealEngine.com/Temporary/SpatialMath }
    using { /Verse.org/Random }
    using { /Verse.org/Simulation }

    instant_respawner_device<public> := class<final>(creative_device):
        @editable:
            ToolTip := TeleporterSettingsToolTip
        Teleporter_Settings<private>:teleporter_settings = teleporter_settings{}

        @editable:
            ToolTip := EliminationSettingsToolTip
        Elimination_Settings<private>:?elimination_settings = false

        @editable_container:
            ToolTip := ChannelsToolTip
        Channels<private>:[]channel_settings = array{}

        OnBegin<override>()<suspends>:void =
            Playspace := GetPlayspace()
            Players := Playspace.GetPlayers()
            InstantRespawnerBuilder := MakeInstantRespawnerBuilder(Playspace, Teleporter_Settings)
            HandleEliminationSettings(InstantRespawnerBuilder, Players)
            HandleChannels(InstantRespawnerBuilder)

        HandleEliminationSettings<private>(InstantRespawnerBuilder:instant_respawner_builder, Players:[]player):void =
            if (EliminationSettings := Elimination_Settings?):
                EliminationInstantRespawner := InstantRespawnerBuilder.MakeEliminationInstantRespawner(EliminationSettings)
                EliminationInstantRespawner.Initialize(Players)

        HandleChannels<private>(InstantRespawnerBuilder:instant_respawner_builder):void =
            for (ChannelSettings : Channels):
                ChannelInstantRespawner := InstantRespawnerBuilder.MakeChannelInstantRespawner(ChannelSettings)
                ChannelInstantRespawner.Initialize()

    TeleporterSettingsToolTip<internal><localizes>:message = "Settings for how teleporters function."
    EliminationSettingsToolTip<internal><localizes>:message = "When set players on elimination will be teleported. Opens up the option to allow eliminators to also be teleported."
    ChannelsToolTip<internal><localizes>:message = "Listening channels; on transmission will activate teleportation."
    
    device_settings_utils<internal> := module:
        teleporter_settings<public> := struct<concrete>:
            @editable_vector_number(float):
                ToolTip := RespawnPositionToolTip
            Respawn_Position:vector3 = vector3{}

            @editable:
                ToolTip := RandomTeleporterToolTip
            Random_Teleporter:logic = false
            
            @editable_container:
                ToolTip := TeleportersToolTip
            Teleporters:[]teleporter_device = array{}

        elimination_settings<public> := struct<concrete>:
            @editable:
                ToolTip := TeleportEliminatorToolTip
            Teleport_Eliminator:logic = false

        channel_settings<public> := struct<concrete>:
            @editable:
                ToolTip := ChannelToolTip
            Channel:channel_device = channel_device{}

            @editable:
                ToolTip := TeleportAllToolTip
            Teleport_All:logic = false

        RespawnPositionToolTip<internal><localizes>:message = "Temporary respawn position for the player, can be set to any value, preferably closest to where they will be teleported and in the open."
        RandomTeleporterToolTip<internal><localizes>:message = "Select random teleporter on player respawn?"
        TeleportersToolTip<internal><localizes>:message = "Each teleporter represents where each team will respawn; for example index 0 will teleport all team 1 players. This is overidden if \'Random_Teleporter\' is true."
        TeleportEliminatorToolTip<internal><localizes>:message = "Teleport the eliminating player?"
        ChannelToolTip<internal><localizes>:message = "Listening channel; if a player is transmitted they are respawned."
        TeleportAllToolTip<internal><localizes>:message = "Teleport all players on channel transmission?"

    instant_respawners<internal> := module:
        MakeInstantRespawnerBuilder<public><constructor>(Playspace:fort_playspace, TeleporterSettings:teleporter_settings) := instant_respawner_builder:
            Playspace := Playspace
            TeamCollection := Playspace.GetTeamCollection()
            TeleporterSettings := TeleporterSettings

        instant_respawner_builder<public> := class<internal><final>:
            Playspace<internal>:fort_playspace
            TeamCollection<internal>:fort_team_collection
            TeleporterSettings<internal>:teleporter_settings

            MakeChannelInstantRespawner<public>(ChannelSettings:channel_settings):channel_instant_respawner =
                ChannelInstantRespawner := channel_instant_respawner:
                    TeleporterSettings := TeleporterSettings
                    TeamCollection := TeamCollection
                    Teams := TeamCollection.GetTeams()
                    Playspace := Playspace
                    TeleportAll := ChannelSettings.Teleport_All
                    ChannelReceivedTransmitEvent := ChannelSettings.Channel.ReceivedTransmitEvent
                ChannelInstantRespawner.InitializeTeleporterLookup()
                return ChannelInstantRespawner

            MakeEliminationInstantRespawner<public>(EliminationSettings:elimination_settings):elimination_instant_respawner =
                EliminationInstantRespawner := elimination_instant_respawner:
                    TeleporterSettings := TeleporterSettings
                    TeamCollection := TeamCollection
                    Teams := TeamCollection.GetTeams()
                    TeleportEliminator := EliminationSettings.Teleport_Eliminator
                    PlayerAddedEvent := Playspace.PlayerAddedEvent()
                    PlayerRemovedEvent := Playspace.PlayerRemovedEvent()
                EliminationInstantRespawner.InitializeTeleporterLookup()
                return EliminationInstantRespawner

            (InstantRespawner:instant_respawner).InitializeTeleporterLookup<private>():void =
                option{InstantRespawner.InitializeTeamTeleporterLookup[]}

        instant_respawner_interface<public> := interface:
            Initialize<public>():void

        instant_respawner<internal> := class<abstract>(instant_respawner_interface):
            TeleporterSettings<internal>:teleporter_settings
            TeamCollection<internal>:fort_team_collection
            Teams<internal>:[]team

            var TeamTeleporterLookup<protected>:[team]teleporter_device = map{}

            InitializeTeamTeleporterLookup<internal><final>()<transacts><decides>:void =
                not TeleporterSettings.Random_Teleporter?
                for (Index->TeamTeleporter : TeleporterSettings.Teleporters, Team := Teams[Index]):
                    set TeamTeleporterLookup[Team] = TeamTeleporter

            (Agent:agent).InstantRespawn<protected><final>()<suspends>:void =
                Sleep(0.1)
                Agent.Respawn(TeleporterSettings.Respawn_Position, rotation{})
                if (TeleporterSettings.Random_Teleporter?):
                    Agent.ToRandomTeleporter()
                else:
                    Agent.ToTeamTeleporter()

            (Agent:agent).ToRandomTeleporter<private><final>():void =
                RandomIndex := GetRandomInt(0, TeleporterSettings.Teleporters.Length - 1)
                if (Teleporter := TeleporterSettings.Teleporters[RandomIndex]):
                    Teleporter.Teleport(Agent)

            (Agent:agent).ToTeamTeleporter<private><final>():void =
                if (Team := TeamCollection.GetTeam[Agent], Teleporter := TeamTeleporterLookup[Team]):
                    Teleporter.Teleport(Agent)

        channel_instant_respawner<public> := class<final><internal>(instant_respawner):
            Playspace<internal>:fort_playspace
            TeleportAll<internal>:logic
            ChannelReceivedTransmitEvent<internal>:listenable(?agent)

            Initialize<override>():void =
                spawn{AwaitChannelTransmission()}

            AwaitChannelTransmission<private>()<suspends>:void =
                loop:
                    MaybeAgent := ChannelReceivedTransmitEvent.Await()
                    if (Agent := MaybeAgent?):
                        if (TeleportAll?):
                            RespawnAllPlayers()
                        else:
                            spawn{Agent.InstantRespawn()}

            RespawnAllPlayers<private>():void =
                Players := Playspace.GetPlayers()
                    for (Player : Players):
                        spawn{Player.InstantRespawn()}

        elimination_instant_respawner<public> := class<final><internal>(instant_respawner):
            TeleportEliminator<internal>:logic
            PlayerAddedEvent<internal>:listenable(player)
            PlayerRemovedEvent<internal>:listenable(player)

            Initialize<override>(Players:[]player):void =
                spawn{AwaitPlayersAdded()}
                HandlePlayersOnInitialization(Players)

            HandlePlayersOnInitialization<private>(Players:[]player):void =
                for (Player : Players):
                    spawn{Player.Await()}

            AwaitPlayersAdded<private>()<suspends>:void =
                loop:
                    Player := PlayerAddedEvent.Await()
                    spawn{Player.Await()}

            (Player:player).Await<private>()<suspends>:void =
                PlayerIsActive := race:
                    Player.AwaitRemoved()
                    Player.AwaitActive()
                if (PlayerIsActive?):
                    spawn{Player.AwaitEliminatedEvents()}

            (Player:player).AwaitRemoved<private>()<suspends>:logic =
                loop:
                    RemovedPlayer := PlayerRemovedEvent.Await()
                    if (Player = RemovedPlayer):
                        return false

            (Player:player).AwaitActive<private>()<suspends>:logic =
                loop:
                    if (Player.IsActive[]):
                        return true
                    Sleep(0.0)

            (Player:player).AwaitEliminatedEvents<private>()<suspends>:void =
                if (FortCharacter := Player.GetFortCharacter[]):
                    EliminatedEvent := FortCharacter.EliminatedEvent()
                    branch{EliminatedEvent.AwaitResults()}
                Player.AwaitRemoved()

            (EliminatedEvent:listenable(elimination_result)).AwaitResults<private>()<suspends>:void =
                loop:
                    EliminationResult := EliminatedEvent.Await()
                    if (EliminatedAgent := EliminationResult.EliminatedCharacter.GetAgent[]):
                        spawn{EliminatedAgent.InstantRespawn()}
                    if (TeleportEliminator?, EliminatingAgent := EliminationResult.EliminatingCharacter?.GetAgent[]):
                        spawn{EliminatingAgent.InstantRespawn()}
