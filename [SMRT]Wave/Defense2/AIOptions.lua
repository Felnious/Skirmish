--
-- Custom Options Definition Table format
--
-- A detailed example of how this format works can be found
-- in the spring source under:
-- AI/Skirmish/NullAI/data/AIOptions.lua
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local options = {
	{ -- section
		key    = 'performance',
		name   = 'Performance Relevant Settings',
		desc   = 'These settings may be relevant for both CPU usage and AI difficulty.',
		type   = 'section',
	},
	{ -- bool
		key     = 'cheating',
		name    = 'LOS vision',
		desc    = 'Enable global sight',
		type    = 'bool',
		section = 'performance',
		def     = true,
	},
	{ -- bool
		key     = 'comm_merge',
		name    = 'Merge neighbour BARbarIAns',
		desc    = 'Merge spatially close BARbarIAn ally commanders',
		type    = 'bool',
		section = 'performance',
		def     = false,
	},
	{ -- bool
		key     = 'ally_base',
		name    = 'Avoid building in allied bases',
		desc    = 'Do not build units near allied factories',
		type    = 'bool',
		section = 'performance',
		def     = true,
	},
-- 	{ -- number (int->uint)
-- 		key     = 'random_seed',
-- 		name    = 'Random seed',
-- 		desc    = 'Seed for random number generator (int)',
-- 		type    = 'number',
-- 		def     = 1337
-- 	},

	{ -- string
		key     = 'disabledunits',
		name    = 'Disabled units',
		desc    = 'Disable usage of specific units.\nSyntax: armwar+armpw+raveparty\nkey: disabledunits',
		type    = 'string',
		def     = 'corhp+armhp+armvp+armap+armkam+armasp+armbrawl+armblade+corbw+corasp+corawac+corape+corcrw+armestor+armuwes+armmstor+armuwadvms+armuwms+cormstor+coruwms+coruwadvms+corestor+coruwes+corlab+corvp+corfink+corbw+corcrw+corape+corawac',
	},
--	{ -- string
--		key     = 'json',
--		name    = 'JSON',
--		desc    = 'Per-AI config.\nkey: json',
--		type    = 'string',
--		def     = '',
--	},

	{ -- bool
		key     = 'game_config',
		name    = 'Load game config',
		desc    = 'Enable loading of game-side config',
		type    = 'bool',
		def     = true,
	},
	{ -- list
		key     = 'profile',
		name    = 'Difficulty profile',
		desc    = 'Difficulty or play-style of AI (see init.as).\nkey: profile',
		type    = 'list',
		def     = 'armbots',
		items   = {
			{
				key  = 'armbots',
				name = 'Armada Bots',
				desc = 'Armada Bots Only',
			},
			{
				key  = 'armveh',
				name = 'Armada Vehicles',
				desc = 'Armada Vehicles Only',
			},
			{
				key  = 'armair',
				name = 'Armada Air',
				desc = 'Armada Air Only',
			},
			{
				key  = 'corbots',
				name = 'Armada Bots',
				desc = 'Armada Bots Only',
			},
			{
				key  = 'corveh',
				name = 'Cortex Vehicles',
				desc = 'Cortex Vehicles Only',
			},
			{
				key  = 'corair',
				name = 'Cortex Air',
				desc = 'Cortex Air Only',
			},
			{
				key  = 'legbots',
				name = 'Legion Bots',
				desc = 'Legion Bots Only',
			},
			{
				key  = 'legveh',
				name = 'Legion Vehicles',
				desc = 'Legion Vehicles Only',
			},
			{
				key  = 'legair',
				name = 'Legion Air',
				desc = 'Legion Air Only',
			},
		},
	},
}

return options
