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
		def     = false,
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
		def     = 'armasp+corasp',
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
		def     = 'extreme',
		items   = {
			{
				key  = 'extreme',
				name = 'Extreme Difficulty',
				desc = 'Playstyle : The Horde Arises, Nothin Survives |Configs by [SMRT]Felnious[AI]',
			},
			{
				key  = 'fiendishdevil',
				name = 'Extreme Difficulty',
				desc = 'Playstyle : Custom AI Tweak for Fiendish Devil Code |Configs by [SMRT]Felnious[AI]',
			},
			{
				key  = 'hard',
				name = 'Hard Difficulty',
				desc = 'Playstyle : Alot of Aggression |Configs by [SMRT]Felnious[AI]',
			},
			{
				key  = 'medium',
				name = 'Medium Difficulty',
				desc = 'Playstyle : Learning Team Strategies |Configs by [SMRT]Felnious[AI]',
			},
			{
				key  = 'easy',
				name = 'Easy Difficulty',
				desc = 'Playstyle : Lazy but Hostile |Configs by [SMRT]Felnious[AI]',
			},
			{
				key  = 'novice',
				name = 'Novice Difficulty',
				desc = 'Playstyle : Very Laid Back |Configs by [SMRT]Felnious[AI]',
			},
		},
	},
}

return options
