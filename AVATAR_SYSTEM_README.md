# Avatar System Setup Guide

## Overview
The avatar system allows players to choose and grow their character avatar as they level up and complete quests. Avatars have stat-based visual indicators, level evolution, and achievement badges.

## Supabase Setup

### Step 1: Create Tables in Supabase

1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Create a new query and copy the entire contents of `SUPABASE_SETUP.sql`
4. Execute the query to create:
   - `avatars` table (static avatar archetypes)
   - `user_avatar_progress` table (track user avatar selection and progress)
   - Indexes for performance
   - Row-Level Security (RLS) policies

### Step 2: Verify Tables and Seed Data

After running the SQL:
1. Check the "avatars" table - you should see 6 avatar archetypes seeded
2. Check the "user_avatar_progress" table - should be empty initially (populated on user selection)

## Avatar Selection Flow

### User Journey
1. **Onboarding** → User completes name, age, profession, schedule (existing)
2. **Avatar Selection** → User selects one of 6 archetypes
3. **Goal Input** → User enters their life goal
4. **Dashboard** → Avatar displays with aura and badges

### Avatar Archetypes

| Archetype | Name | Default Stat | Color | Description |
|-----------|------|--------------|-------|-------------|
| knight | Noble Knight | Discipline | Gold (#FFD54F) | Steadfast warrior, strong in discipline |
| sage | Mystic Sage | Knowledge | Blue (#5B7FFF) | Seeker of knowledge, arcane arts |
| rogue | Swift Rogue | Social | Teal (#4ECDC4) | Quick & cunning, balanced |
| guardian | Steadfast Guardian | Health | Red (#FF6B4A) | Protector of wellness, vitality |
| mage | Arcane Mage | Knowledge | Purple (#9D5FFF) | Master of mystical forces |
| druid | Natural Druid | Health | Green (#52C977) | Harmonious, balanced, resilient |

## Avatar Display Features

### 1. Visual Elements
- **Main Avatar**: Circle with initial letter and level (e.g., "K LVL 7")
- **Aura Glow**: Pulsing glow around avatar reflecting dominant stat color
- **Stat Indicator**: Badge showing emoji of dominant stat (bottom of circle)
- **Achievement Badges**: Up to 3 recent badges in bottom-right corner

### 2. Level-Based Evolution
Avatar stages unlock every 5 levels:
- Level 1-5: Stage 1
- Level 6-10: Stage 2
- Level 11-15: Stage 3
- Level 16-20: Stage 4
- Level 21+: Stage 5+

Currently uses placeholder (first letter), but ready for character art at `assets/avatars/{archetype}_stage_{N}.png`

### 3. Stat-Based Aura Colors
- **Health (🏃)**: Red-Orange (#FF6B4A)
- **Knowledge (📚)**: Blue-Purple (#5B7FFF)
- **Discipline (⚡)**: Gold-Yellow (#FFD54F)
- **Social (🧍)**: Teal-Green (#4ECDC4)

### 4. Achievement Badges
| Badge ID | Name | Unlock Condition |
|----------|------|------------------|
| first_quest | First Step | Complete 1 quest |
| first_10_quests | On a Roll | Complete 10 quests |
| quest_master | Quest Master | Complete 50 quests |
| legend | Living Legend | Complete 100 quests |
| level_5 | Rising Star | Reach Level 5 |
| level_10 | Seasoned Warrior | Reach Level 10 |
| level_20 | Legendary Hero | Reach Level 20 |

## Integration Points

### Files Modified
- `lib/screens/dashboard_screen.dart` - Avatar display in header
- `lib/screens/profile_screen.dart` - Large avatar in profile
- `lib/screens/onboarding_screen.dart` - Navigation to avatar selection
- `lib/widgets/level_up_overlay.dart` - Ready for avatar integration

### Files Created
- `lib/models/avatar.dart` - Avatar data model
- `lib/models/user_avatar_progress.dart` - Progress tracking model
- `lib/services/avatar_service.dart` - Supabase API layer
- `lib/widgets/avatar_display.dart` - Avatar rendering component
- `lib/screens/avatar_selection_screen.dart` - Onboarding step
- `lib/theme/avatar_theme.dart` - Avatar colors and config

## Data Sync

### Automatic Sync Points
1. **Dashboard Load** → Loads user's avatar and progress
2. **Quest Complete** → Updates level, syncs badges
3. **Level Up** → Loads new level variant, checks new badges
4. **Stat Change** → Recomputes dominant stat, updates aura

### Sync Methods
```dart
// Load avatar progress
await AvatarService().getUserAvatarProgress(userId)

// Update when level changes
await AvatarService().updateLevel(userId, newLevel)

// Update dominant stat
await AvatarService().updateDominantStat(userId, statsMap)

// Check unlocked badges
AvatarService().checkBadgesUnlocked(level, completedQuests)

// Save badges
await AvatarService().updateBadges(userId, badgeList)
```

## Future Enhancements

### Asset Integration
When ready to add character art:
1. Add PNG files to `assets/avatars/`
2. Naming: `{archetype}_stage_{1-5}.png` (256x256px)
3. Update `AvatarDisplay` widget to load images
4. Add animation on stage transitions

### Additional Features
- [ ] Avatar name customization
- [ ] Equipment slots (armor, accessories)
- [ ] Avatar skill tree
- [ ] Social avatar comparison
- [ ] Avatar marketplace/trading
- [ ] Seasonal avatar cosmetics

## Testing Checklist

- [ ] Avatar selection saves to Supabase
- [ ] Avatar persists on logout/login
- [ ] Avatar displays correctly on dashboard (44x44)
- [ ] Avatar displays correctly on profile (88x88)
- [ ] Stat changes update aura color
- [ ] Badges unlock and display
- [ ] Multiple users have independent avatars
- [ ] Level changes trigger variant lookup
- [ ] Aura animation plays smoothly

## Troubleshooting

### Avatar Not Loading
1. Check Supabase connection in `SupabaseConfig`
2. Verify `user_avatar_progress` table has user's record
3. Check that `selected_avatar_id` references valid avatar

### Badges Not Appearing
1. Verify `checkBadgesUnlocked()` logic in service
2. Check that badges are being saved to `equipped_badges`
3. Confirm badge IDs match `AvatarTheme.badgeEmojis`

### Aura Not Changing
1. Verify `dominant_stat` is being updated
2. Check `AvatarTheme.statColors` has the stat key
3. Ensure `AvatarDisplay` is rebuilding (check state management)

## Performance Notes

- Aura glow uses `ColorFilter` (efficient)
- Avatar loading is async to avoid UI blocks
- Badge stacking uses `Stack` with `Positioned` (minimal overhead)
- Stat updates debounced to prevent excessive Supabase writes
