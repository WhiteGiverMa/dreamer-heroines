using System;
using System.Collections.Generic;
using Godot;

namespace DreamerHeroines.Data
{
    /// <summary>
    /// 游戏配置管理器 - 管理所有游戏内配置数据
    /// 提供全局访问点，支持热重载
    /// </summary>
    public static class GameConfig
    {
        #region Fields
        private static readonly Dictionary<string, object> _configValues = new Dictionary<string, object>();
        private static readonly Dictionary<string, Action> _reloadCallbacks = new Dictionary<string, Action>();
        #endregion

        #region Player Config
        /// <summary>
        /// 玩家配置
        /// </summary>
        public static class Player
        {
            public static float BaseMoveSpeed { get; set; } = 200f;
            public static float SprintSpeed { get; set; } = 350f;
            public static float CrouchSpeed { get; set; } = 100f;
            public static float JumpForce { get; set; } = 400f;
            public static float GravityScale { get; set; } = 1.0f;
            public static int MaxHealth { get; set; } = 100;
            public static int MaxArmor { get; set; } = 100;
            public static float HealthRegenRate { get; set; } = 5f;
            public static float HealthRegenDelay { get; set; } = 5f;
            public static float InvulnerabilityTime { get; set; } = 1f;
            public static int MaxWeapons { get; set; } = 3;
            public static float AimAssistStrength { get; set; } = 0.3f;
            public static float AimAssistRange { get; set; } = 300f;
        }
        #endregion

        #region Combat Config
        /// <summary>
        /// 战斗配置
        /// </summary>
        public static class Combat
        {
            public static float CriticalHitMultiplier { get; set; } = 2.0f;
            public static float CriticalHitChance { get; set; } = 0.05f;
            public static float HeadshotMultiplier { get; set; } = 3.0f;
            public static float DamageNumberDisplayTime { get; set; } = 1.0f;
            public static float HitMarkerDisplayTime { get; set; } = 0.1f;
            public static float KnockbackMultiplier { get; set; } = 1.0f;
            public static float EnemyDamageMultiplier { get; set; } = 1.0f;
            public static float PlayerDamageMultiplier { get; set; } = 1.0f;
            public static int MaxProjectiles { get; set; } = 100;
            public static float ProjectileLifetime { get; set; } = 5f;
        }
        #endregion

        #region Economy Config
        /// <summary>
        /// 经济配置
        /// </summary>
        public static class Economy
        {
            public static int StartingGold { get; set; } = 0;
            public static int StartingGems { get; set; } = 0;
            public static int KillRewardBase { get; set; } = 10;
            public static float KillRewardMultiplier { get; set; } = 1.0f;
            public static int MissionCompleteReward { get; set; } = 100;
            public static int SecretFoundReward { get; set; } = 50;
            public static float SellPriceMultiplier { get; set; } = 0.5f;
            public static int ReviveCost { get; set; } = 100;
            public static int ContinueCostBase { get; set; } = 50;
            public static float ContinueCostMultiplier { get; set; } = 1.5f;
        }
        #endregion

        #region Difficulty Config
        /// <summary>
        /// 难度配置
        /// </summary>
        public static class Difficulty
        {
            public static float[] EnemyHealthMultipliers { get; set; } = new float[] { 0.8f, 1.0f, 1.3f, 1.6f, 2.0f };
            public static float[] EnemyDamageMultipliers { get; set; } = new float[] { 0.7f, 1.0f, 1.4f, 1.8f, 2.5f };
            public static float[] EnemySpeedMultipliers { get; set; } = new float[] { 0.9f, 1.0f, 1.1f, 1.2f, 1.3f };
            public static float[] XPMultipliers { get; set; } = new float[] { 1.2f, 1.0f, 0.9f, 0.8f, 0.7f };
            public static float[] GoldMultipliers { get; set; } = new float[] { 1.1f, 1.0f, 0.95f, 0.9f, 0.85f };
            public static int[] MaxLives { get; set; } = new int[] { 5, 3, 2, 1, 1 };
            public static bool[] Permadeath { get; set; } = new bool[] { false, false, false, false, true };

            public static float GetEnemyHealthMultiplier(int difficulty) =>
                EnemyHealthMultipliers[Mathf.Clamp(difficulty, 0, 4)];

            public static float GetEnemyDamageMultiplier(int difficulty) =>
                EnemyDamageMultipliers[Mathf.Clamp(difficulty, 0, 4)];

            public static float GetEnemySpeedMultiplier(int difficulty) =>
                EnemySpeedMultipliers[Mathf.Clamp(difficulty, 0, 4)];

            public static float GetXPMultiplier(int difficulty) => XPMultipliers[Mathf.Clamp(difficulty, 0, 4)];

            public static float GetGoldMultiplier(int difficulty) => GoldMultipliers[Mathf.Clamp(difficulty, 0, 4)];

            public static int GetMaxLives(int difficulty) => MaxLives[Mathf.Clamp(difficulty, 0, 4)];

            public static bool IsPermadeath(int difficulty) => Permadeath[Mathf.Clamp(difficulty, 0, 4)];
        }
        #endregion

        #region Audio Config
        /// <summary>
        /// 音频配置
        /// </summary>
        public static class Audio
        {
            public static float MasterVolume { get; set; } = 1.0f;
            public static float MusicVolume { get; set; } = 0.8f;
            public static float SFXVolume { get; set; } = 1.0f;
            public static float VoiceVolume { get; set; } = 1.0f;
            public static float AmbientVolume { get; set; } = 0.7f;
            public static int MaxConcurrentSounds { get; set; } = 32;
            public static float SoundDistanceScale { get; set; } = 1.0f;
            public static bool EnableSpatialAudio { get; set; } = true;
            public static bool EnableReverb { get; set; } = true;
        }
        #endregion

        #region Visual Config
        /// <summary>
        /// 视觉配置
        /// </summary>
        public static class Visual
        {
            public static int TargetFPS { get; set; } = 60;
            public static bool VSync { get; set; } = true;
            public static bool Fullscreen { get; set; } = false;
            public static int ResolutionScale { get; set; } = 100;
            public static bool Bloom { get; set; } = true;
            public static bool MotionBlur { get; set; } = false;
            public static bool ScreenSpaceReflections { get; set; } = false;
            public static int ShadowQuality { get; set; } = 2;
            public static int TextureQuality { get; set; } = 2;
            public static bool ShowFPS { get; set; } = false;
            public static bool ShowDamageNumbers { get; set; } = true;
            public static bool ShowHitMarkers { get; set; } = true;
            public static float ScreenShakeIntensity { get; set; } = 1.0f;
            public static float DamageNumberScale { get; set; } = 1.0f;
        }
        #endregion

        #region Input Config
        /// <summary>
        /// 输入配置
        /// </summary>
        public static class Input
        {
            public static float MouseSensitivity { get; set; } = 1.0f;
            public static bool InvertMouseY { get; set; } = false;
            public static bool InvertMouseX { get; set; } = false;
            public static float ControllerSensitivity { get; set; } = 1.0f;
            public static float ControllerDeadzone { get; set; } = 0.1f;
            public static bool AimAssist { get; set; } = true;
            public static float AimAssistStrength { get; set; } = 0.3f;
            public static bool ToggleSprint { get; set; } = false;
            public static bool ToggleCrouch { get; set; } = false;
            public static bool ToggleADS { get; set; } = false;
        }
        #endregion

        #region Gameplay Config
        /// <summary>
        /// 游戏玩法配置
        /// </summary>
        public static class Gameplay
        {
            public static bool AutoSave { get; set; } = true;
            public static int AutoSaveInterval { get; set; } = 300;
            public static int MaxSaveSlots { get; set; } = 5;
            public static bool PermadeathMode { get; set; } = false;
            public static bool IronmanMode { get; set; } = false;
            public static float TimeScale { get; set; } = 1.0f;
            public static bool PauseOnFocusLost { get; set; } = true;
            public static bool SkipCutscenes { get; set; } = false;
            public static bool ShowTutorials { get; set; } = true;
            public static string Language { get; set; } = "zh_CN";
            public static bool Subtitles { get; set; } = true;
        }
        #endregion

        #region Debug Config
        /// <summary>
        /// 调试配置（仅在DEBUG模式下生效）
        /// </summary>
        public static class Debug
        {
            public static bool ShowDebugInfo { get; set; } = false;
            public static bool GodMode { get; set; } = false;
            public static bool InfiniteAmmo { get; set; } = false;
            public static bool NoClip { get; set; } = false;
            public static bool ShowCollisionShapes { get; set; } = false;
            public static bool ShowNavigationMesh { get; set; } = false;
            public static bool ShowFPSGraph { get; set; } = false;
            public static bool LogAllEvents { get; set; } = false;
            public static float TimeScaleOverride { get; set; } = 1.0f;
        }
        #endregion

        #region Public Methods
        /// <summary>
        /// 设置配置值
        /// </summary>
        public static void SetValue<T>(string key, T value)
        {
            _configValues[key] = value!;
        }

        /// <summary>
        /// 获取配置值
        /// </summary>
        public static T? GetValue<T>(string key, T defaultValue)
        {
            if (_configValues.TryGetValue(key, out var value) && value is T typedValue)
            {
                return typedValue;
            }
            return defaultValue;
        }

        /// <summary>
        /// 注册配置重载回调
        /// </summary>
        public static void RegisterReloadCallback(string configName, Action callback)
        {
            _reloadCallbacks[configName] = callback;
        }

        /// <summary>
        /// 从文件加载配置
        /// </summary>
        public static void LoadFromFile(string path)
        {
            if (!FileAccess.FileExists(path))
            {
                GD.PushWarning($"Config file not found: {path}");
                return;
            }

            try
            {
                using var file = FileAccess.Open(path, FileAccess.ModeFlags.Read);
                string json = file.GetAsText();
                ParseJsonConfig(json);
                GD.Print($"Config loaded from: {path}");
            }
            catch (Exception ex)
            {
                GD.PushError($"Failed to load config: {ex.Message}");
            }
        }

        /// <summary>
        /// 保存配置到文件
        /// </summary>
        public static void SaveToFile(string path)
        {
            try
            {
                string json = SerializeToJson();
                using var file = FileAccess.Open(path, FileAccess.ModeFlags.Write);
                file.StoreString(json);
                GD.Print($"Config saved to: {path}");
            }
            catch (Exception ex)
            {
                GD.PushError($"Failed to save config: {ex.Message}");
            }
        }

        /// <summary>
        /// 重置所有配置为默认值
        /// </summary>
        public static void ResetToDefaults()
        {
            // 玩家配置
            Player.BaseMoveSpeed = 200f;
            Player.SprintSpeed = 350f;
            Player.CrouchSpeed = 100f;
            Player.JumpForce = 400f;
            Player.GravityScale = 1.0f;
            Player.MaxHealth = 100;
            Player.MaxArmor = 100;

            // 战斗配置
            Combat.CriticalHitMultiplier = 2.0f;
            Combat.CriticalHitChance = 0.05f;

            // 音频配置
            Audio.MasterVolume = 1.0f;
            Audio.MusicVolume = 0.8f;
            Audio.SFXVolume = 1.0f;

            // 视觉配置
            Visual.TargetFPS = 60;
            Visual.VSync = true;
            Visual.Fullscreen = false;

            // 输入配置
            Input.MouseSensitivity = 1.0f;
            Input.InvertMouseY = false;

            // 游戏配置
            Gameplay.AutoSave = true;
            Gameplay.TimeScale = 1.0f;

            _configValues.Clear();
            GD.Print("Config reset to defaults");
        }

        /// <summary>
        /// 应用配置到游戏设置
        /// </summary>
        public static void ApplyToGame()
        {
            // 应用音频设置
            AudioServer.SetBusVolumeDb(0, Mathf.LinearToDb(Audio.MasterVolume));
            // 应用显示设置
            Engine.MaxFps = Visual.TargetFPS;
            Engine.TimeScale = Gameplay.TimeScale;
            // 应用窗口设置
            DisplayServer.WindowSetMode(
                Visual.Fullscreen ? DisplayServer.WindowMode.Fullscreen : DisplayServer.WindowMode.Windowed
            );
            // 应用VSync
            DisplayServer.WindowSetVsyncMode(
                Visual.VSync ? DisplayServer.VSyncMode.Enabled : DisplayServer.VSyncMode.Disabled
            );

            GD.Print("Config applied to game");
        }
        #endregion

        #region Private Methods
        private static void ParseJsonConfig(string json)
        {
            // 简化的JSON解析，实际项目中应使用完整的JSON解析器
            // 这里仅作为示例
            GD.Print("Parsing config JSON...");
        }

        private static string SerializeToJson()
        {
            // 简化的JSON序列化，实际项目中应使用完整的JSON序列化器
            return "{}";
        }
        #endregion
    }

    /// <summary>
    /// 配置加载器 - 用于从资源文件加载配置
    /// </summary>
    public class ConfigLoader
    {
        /// <summary>
        /// 从JSON文件加载武器配置
        /// </summary>
        public static void LoadWeaponConfig(string path)
        {
            if (!FileAccess.FileExists(path))
            {
                GD.PushWarning($"Weapon config not found: {path}");
                return;
            }

            // TODO: 实现武器配置加载
            GD.Print($"Loading weapon config from: {path}");
        }

        /// <summary>
        /// 从JSON文件加载敌人配置
        /// </summary>
        public static void LoadEnemyConfig(string path)
        {
            if (!FileAccess.FileExists(path))
            {
                GD.PushWarning($"Enemy config not found: {path}");
                return;
            }

            // TODO: 实现敌人配置加载
            GD.Print($"Loading enemy config from: {path}");
        }

        /// <summary>
        /// 从JSON文件加载关卡配置
        /// </summary>
        public static void LoadLevelConfig(string path)
        {
            if (!FileAccess.FileExists(path))
            {
                GD.PushWarning($"Level config not found: {path}");
                return;
            }

            // TODO: 实现关卡配置加载
            GD.Print($"Loading level config from: {path}");
        }
    }
}
