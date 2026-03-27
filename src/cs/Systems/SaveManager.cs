using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using DreamerHeroines.Data;
using Godot;

namespace DreamerHeroines.Systems
{
    /// <summary>
    /// 保存管理器 - 单例模式
    /// 处理存档/读档、自动保存、多存档槽管理
    /// </summary>
    public partial class SaveManager : Node
    {
        #region Singleton
        private static SaveManager? _instance;
        public static SaveManager Instance
        {
            get
            {
                if (_instance == null)
                {
                    GD.PushWarning("SaveManager instance is null! Make sure it's added to autoload.");
                }
                return _instance!;
            }
        }
        #endregion

        #region Constants
        private const string SAVE_FOLDER = "user://saves/";
        private const string SAVE_EXTENSION = ".sav";
        private const string BACKUP_EXTENSION = ".bak";
        private const string SETTINGS_FILE = "user://settings.json";
        private const int MAX_SAVE_SLOTS = 10;
        private const int MAX_BACKUP_COUNT = 3;
        private const double AUTO_SAVE_INTERVAL = 300.0; // 5分钟
        #endregion

        #region Fields
        private SaveData? _currentSaveData;
        private int _currentSlot = -1;
        private bool _isSaving = false;
        private bool _isLoading = false;
        private double _autoSaveTimer = 0.0;
        private bool _autoSaveEnabled = true;
        private readonly Queue<SaveOperation> _saveQueue = new Queue<SaveOperation>();
        private PlayerData? _cachedPlayerData;
        private static readonly JsonSerializerOptions _settingsJsonOptions = new JsonSerializerOptions
        {
            WriteIndented = true,
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        };
        #endregion

        #region Properties
        /// <summary>
        /// 系统是否已初始化
        /// </summary>
        public bool IsInitialized { get; private set; } = false;

        /// <summary>
        /// 初始化完成事件，参数为系统名称
        /// </summary>
        public event Action<string>? SystemReady;

        /// <summary>
        /// 当前存档数据
        /// </summary>
        public SaveData? CurrentSaveData => _currentSaveData;

        /// <summary>
        /// 当前存档槽索引
        /// </summary>
        public int CurrentSlot => _currentSlot;

        /// <summary>
        /// 是否正在保存
        /// </summary>
        public bool IsSaving => _isSaving;

        /// <summary>
        /// 是否正在加载
        /// </summary>
        public bool IsLoading => _isLoading;

        /// <summary>
        /// 是否有当前存档
        /// </summary>
        public bool HasCurrentSave => _currentSaveData != null;

        /// <summary>
        /// 是否启用自动保存
        /// </summary>
        public bool AutoSaveEnabled
        {
            get => _autoSaveEnabled;
            set => _autoSaveEnabled = value;
        }

        /// <summary>
        /// 自动保存间隔（秒）
        /// </summary>
        public double AutoSaveInterval { get; set; } = AUTO_SAVE_INTERVAL;

        /// <summary>
        /// 距离下次自动保存的时间
        /// </summary>
        public double TimeUntilAutoSave => Math.Max(0, AutoSaveInterval - _autoSaveTimer);
        #endregion

        #region Signals
        [Signal]
        public delegate void SaveStartedEventHandler(int slot);

        [Signal]
        public delegate void SaveCompletedEventHandler(int slot, bool success);

        [Signal]
        public delegate void LoadStartedEventHandler(int slot);

        [Signal]
        public delegate void LoadCompletedEventHandler(int slot, bool success);

        [Signal]
        public delegate void AutoSaveTriggeredEventHandler();

        [Signal]
        public delegate void SaveDeletedEventHandler(int slot);

        [Signal]
        public delegate void SaveDataChangedEventHandler();
        #endregion

        #region Initialization
        /// <summary>
        /// 初始化系统 - 由 BootSequence 调用
        /// </summary>
        public void Initialize()
        {
            if (IsInitialized)
                return;

            // 执行任何必要的初始化逻辑

            IsInitialized = true;
            SystemReady?.Invoke("csharp_save_manager");
            GD.Print("[CSharpSaveManager] 初始化完成");
        }
        #endregion

        #region Godot Lifecycle
        public override void _Ready()
        {
            if (_instance != null)
            {
                GD.PushWarning("Multiple SaveManager instances detected! Destroying duplicate.");
                QueueFree();
                return;
            }

            _instance = this;
            ProcessMode = ProcessModeEnum.Always;

            // 确保保存目录存在
            EnsureSaveDirectory();

            GD.Print("SaveManager initialized");
            GD.Print($"Save directory: {ProjectSettings.GlobalizePath(SAVE_FOLDER)}");
        }

        public override void _ExitTree()
        {
            if (_instance == this)
            {
                _instance = null;
            }
        }

        public override void _Process(double delta)
        {
            // 处理自动保存
            var gameManager = GetNode<Node>("/root/GameManager");
            bool isPlaying = gameManager?.Call("is_playing").AsBool() ?? false;
            if (_autoSaveEnabled && _currentSaveData != null && isPlaying)
            {
                _autoSaveTimer += delta;
                if (_autoSaveTimer >= AutoSaveInterval)
                {
                    _autoSaveTimer = 0.0;
                    PerformAutoSave();
                }
            }

            // 处理保存队列
            ProcessSaveQueue();
        }
        #endregion

        #region Save Operations
        /// <summary>
        /// 创建新存档
        /// </summary>
        public SaveData CreateNewSave(int slot, string displayName)
        {
            if (slot < 0 || slot >= MAX_SAVE_SLOTS)
            {
                throw new ArgumentOutOfRangeException(nameof(slot), $"Slot must be between 0 and {MAX_SAVE_SLOTS - 1}");
            }

            var saveData = SaveData.CreateNew(slot, displayName);
            _currentSaveData = saveData;
            _currentSlot = slot;
            _autoSaveTimer = 0.0;

            // 立即保存
            SaveToSlot(slot);

            EmitSignal(SignalName.SaveDataChanged);
            GD.Print($"Created new save in slot {slot}: {displayName}");

            return saveData;
        }

        /// <summary>
        /// 保存到指定槽位
        /// </summary>
        public async void SaveToSlot(int slot, bool showNotification = true)
        {
            if (_isSaving || _currentSaveData == null)
            {
                // 添加到队列
                _saveQueue.Enqueue(new SaveOperation { Slot = slot, ShowNotification = showNotification });
                return;
            }

            _isSaving = true;
            EmitSignal(SignalName.SaveStarted, slot);

            try
            {
                // 更新存档数据
                UpdateSaveData();
                _currentSaveData.UpdateSaveTime();
                _currentSaveData.SlotIndex = slot;

                // 创建备份
                CreateBackup(slot);

                // 序列化并保存
                string filePath = GetSaveFilePath(slot);
                string json = SaveSerializer.Serialize(_currentSaveData);

                // 使用文件访问保存
                using var file = FileAccess.Open(filePath, FileAccess.ModeFlags.Write);
                if (file != null)
                {
                    file.StoreString(json);
                    file.Close();

                    _currentSlot = slot;
                    EmitSignal(SignalName.SaveCompleted, slot, true);

                    if (showNotification)
                    {
                        GD.Print($"Game saved to slot {slot}");
                    }
                }
                else
                {
                    throw new Exception("Failed to open file for writing");
                }
            }
            catch (Exception ex)
            {
                GD.PushError($"Failed to save game: {ex.Message}");
                EmitSignal(SignalName.SaveCompleted, slot, false);
            }
            finally
            {
                _isSaving = false;
            }
        }

        /// <summary>
        /// 快速保存（保存到当前槽位）
        /// </summary>
        public void QuickSave()
        {
            if (_currentSlot >= 0)
            {
                SaveToSlot(_currentSlot);
            }
            else
            {
                // 如果没有当前槽位，保存到第一个空槽
                for (int i = 0; i < MAX_SAVE_SLOTS; i++)
                {
                    if (!HasSaveInSlot(i))
                    {
                        SaveToSlot(i);
                        break;
                    }
                }
            }
        }

        /// <summary>
        /// 从指定槽位加载
        /// </summary>
        public bool LoadFromSlot(int slot)
        {
            if (_isLoading)
            {
                GD.PushWarning("Already loading a save!");
                return false;
            }

            string filePath = GetSaveFilePath(slot);
            if (!FileAccess.FileExists(filePath))
            {
                GD.PushWarning($"No save file found in slot {slot}");
                return false;
            }

            _isLoading = true;
            EmitSignal(SignalName.LoadStarted, slot);

            try
            {
                using var file = FileAccess.Open(filePath, FileAccess.ModeFlags.Read);
                if (file == null)
                {
                    throw new Exception("Failed to open save file");
                }

                string json = file.GetAsText();
                file.Close();

                var saveData = SaveSerializer.Deserialize(json);

                if (saveData == null || !SaveSerializer.Validate(saveData))
                {
                    throw new Exception("Invalid save data");
                }

                _currentSaveData = saveData;
                _currentSlot = slot;
                _autoSaveTimer = 0.0;

                // 应用存档数据到游戏
                ApplySaveData();

                EmitSignal(SignalName.LoadCompleted, slot, true);
                EmitSignal(SignalName.SaveDataChanged);
                GD.Print($"Game loaded from slot {slot}");

                return true;
            }
            catch (Exception ex)
            {
                GD.PushError($"Failed to load save: {ex.Message}");
                EmitSignal(SignalName.LoadCompleted, slot, false);
                return false;
            }
            finally
            {
                _isLoading = false;
            }
        }

        /// <summary>
        /// 删除存档
        /// </summary>
        public bool DeleteSave(int slot)
        {
            string filePath = GetSaveFilePath(slot);

            if (!FileAccess.FileExists(filePath))
            {
                return false;
            }

            try
            {
                // 删除主存档文件
                DirAccess.RemoveAbsolute(filePath);

                // 删除备份文件
                for (int i = 1; i <= MAX_BACKUP_COUNT; i++)
                {
                    string backupPath = GetBackupFilePath(slot, i);
                    if (FileAccess.FileExists(backupPath))
                    {
                        DirAccess.RemoveAbsolute(backupPath);
                    }
                }

                // 如果删除的是当前存档，清除当前数据
                if (_currentSlot == slot)
                {
                    _currentSaveData = null;
                    _currentSlot = -1;
                    EmitSignal(SignalName.SaveDataChanged);
                }

                EmitSignal(SignalName.SaveDeleted, slot);
                GD.Print($"Save deleted from slot {slot}");

                return true;
            }
            catch (Exception ex)
            {
                GD.PushError($"Failed to delete save: {ex.Message}");
                return false;
            }
        }

        /// <summary>
        /// 获取所有存档摘要
        /// </summary>
        public SaveSummary[] GetAllSaveSummaries()
        {
            var summaries = new List<SaveSummary>();

            for (int i = 0; i < MAX_SAVE_SLOTS; i++)
            {
                summaries.Add(GetSaveSummary(i));
            }

            return summaries.ToArray();
        }

        /// <summary>
        /// 获取指定槽位的存档摘要
        /// </summary>
        public SaveSummary GetSaveSummary(int slot)
        {
            string filePath = GetSaveFilePath(slot);

            if (!FileAccess.FileExists(filePath))
            {
                return new SaveSummary { SlotIndex = slot };
            }

            try
            {
                using var file = FileAccess.Open(filePath, FileAccess.ModeFlags.Read);
                if (file == null)
                {
                    return new SaveSummary { SlotIndex = slot };
                }

                string json = file.GetAsText();
                file.Close();

                var saveData = SaveSerializer.Deserialize(json);
                return saveData?.GetSummary() ?? new SaveSummary { SlotIndex = slot };
            }
            catch
            {
                return new SaveSummary { SlotIndex = slot };
            }
        }

        /// <summary>
        /// 检查槽位是否有存档
        /// </summary>
        public bool HasSaveInSlot(int slot)
        {
            return FileAccess.FileExists(GetSaveFilePath(slot));
        }

        /// <summary>
        /// 获取第一个空槽位
        /// </summary>
        public int GetFirstEmptySlot()
        {
            for (int i = 0; i < MAX_SAVE_SLOTS; i++)
            {
                if (!HasSaveInSlot(i))
                {
                    return i;
                }
            }
            return -1;
        }
        #endregion

        #region Auto Save
        /// <summary>
        /// 执行自动保存
        /// </summary>
        private void PerformAutoSave()
        {
            if (_currentSlot < 0)
            {
                // 如果没有当前槽位，不自动保存
                return;
            }

            GD.Print("Auto-saving...");
            EmitSignal(SignalName.AutoSaveTriggered);
            SaveToSlot(_currentSlot, false);
        }

        /// <summary>
        /// 重置自动保存计时器
        /// </summary>
        public void ResetAutoSaveTimer()
        {
            _autoSaveTimer = 0.0;
        }
        #endregion

        #region Player Data
        /// <summary>
        /// 获取玩家数据
        /// </summary>
        public PlayerData? GetPlayerData()
        {
            if (_cachedPlayerData == null && _currentSaveData != null)
            {
                _cachedPlayerData = ConvertToPlayerData(_currentSaveData.Player);
            }
            return _cachedPlayerData;
        }

        /// <summary>
        /// 更新玩家数据
        /// </summary>
        public void UpdatePlayerData(PlayerData playerData)
        {
            _cachedPlayerData = playerData;
            if (_currentSaveData != null)
            {
                _currentSaveData.Player = ConvertToSaveData(playerData);
            }
        }
        #endregion

        #region Settings
        /// <summary>
        /// 保存游戏设置（GDScript Dictionary 入口）
        /// </summary>
        public void SaveSettings(Godot.Collections.Dictionary settings)
        {
            var current = LoadSettings();
            var merged = MergeSettingsFromDictionary(current, settings);
            SaveSettings(merged);
        }

        /// <summary>
        /// 保存游戏设置（C# 类型入口）
        /// </summary>
        public void SaveSettings(SettingsSaveData settings)
        {
            try
            {
                var payload = LoadRawSettingsPayload();
                RemoveKnownSettingsAliasKeys(payload);
                ApplyCanonicalSettingsPayload(payload, settings);

                string json = JsonSerializer.Serialize(payload, _settingsJsonOptions);
                using var file = FileAccess.Open(SETTINGS_FILE, FileAccess.ModeFlags.Write);
                if (file != null)
                {
                    file.StoreString(json);
                    file.Close();
                    GD.Print("Settings saved via C# SaveManager");
                }
                else
                {
                    throw new Exception("Failed to open settings file for writing");
                }
            }
            catch (Exception ex)
            {
                GD.PushError($"Failed to save settings: {ex.Message}");
            }
        }

        /// <summary>
        /// 加载游戏设置
        /// </summary>
        public SettingsSaveData LoadSettings()
        {
            var defaults = new SettingsSaveData();

            if (!FileAccess.FileExists(SETTINGS_FILE))
            {
                return defaults;
            }

            try
            {
                using var file = FileAccess.Open(SETTINGS_FILE, FileAccess.ModeFlags.Read);
                if (file == null)
                {
                    return defaults;
                }

                string json = file.GetAsText();
                file.Close();

                if (string.IsNullOrWhiteSpace(json))
                {
                    return defaults;
                }

                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;
                return ParseSettingsElement(root, defaults);
            }
            catch (Exception ex)
            {
                GD.PushError($"Failed to load settings: {ex}");
                return defaults;
            }
        }

        /// <summary>
        /// 为 GDScript 返回兼容字段命名的 Dictionary
        /// </summary>
        public Godot.Collections.Dictionary LoadSettingsDictionary()
        {
            var settings = LoadSettings();
            return ToGDScriptSettingsDictionary(settings);
        }

        private Dictionary<string, object?> LoadRawSettingsPayload()
        {
            var payload = new Dictionary<string, object?>(StringComparer.Ordinal);

            if (!FileAccess.FileExists(SETTINGS_FILE))
            {
                return payload;
            }

            try
            {
                using var file = FileAccess.Open(SETTINGS_FILE, FileAccess.ModeFlags.Read);
                if (file == null)
                {
                    return payload;
                }

                string json = file.GetAsText();
                file.Close();

                if (string.IsNullOrWhiteSpace(json))
                {
                    return payload;
                }

                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;
                if (root.ValueKind != JsonValueKind.Object)
                {
                    return payload;
                }

                foreach (var property in root.EnumerateObject())
                {
                    payload[property.Name] = property.Value.Clone();
                }
            }
            catch (Exception ex)
            {
                GD.PushWarning($"Failed to load raw settings payload for merge: {ex.Message}");
            }

            return payload;
        }

        private static void RemoveKnownSettingsAliasKeys(Dictionary<string, object?> payload)
        {
            var knownAliases = new[]
            {
                "master_volume",
                "masterVolume",
                "MasterVolume",
                "music_volume",
                "musicVolume",
                "MusicVolume",
                "sfx_volume",
                "sfxVolume",
                "SFXVolume",
                "ui_volume",
                "uiVolume",
                "UiVolume",
                "UIVolume",
                "mouse_sensitivity",
                "mouseSensitivity",
                "MouseSensitivity",
                "crosshair_size",
                "crosshairSize",
                "CrosshairSize",
                "crosshair_alpha",
                "crosshairAlpha",
                "CrosshairAlpha",
                "show_center_dot",
                "showCenterDot",
                "ShowCenterDot",
                "center_dot_size",
                "centerDotSize",
                "CenterDotSize",
                "spread_increase_per_shot",
                "spreadIncreasePerShot",
                "SpreadIncreasePerShot",
                "crosshair_recovery_rate",
                "crosshairRecoveryRate",
                "CrosshairRecoveryRate",
                "max_spread_multiplier",
                "maxSpreadMultiplier",
                "MaxSpreadMultiplier",
                "invert_mouse_y",
                "invertMouseY",
                "InvertMouseY",
                "show_damage_numbers",
                "showDamageNumbers",
                "ShowDamageNumbers",
                "screen_shake",
                "screenShake",
                "ScreenShake",
                "target_frame_rate",
                "targetFrameRate",
                "TargetFrameRate",
                "vsync",
                "vSync",
                "VSync",
                "fullscreen",
                "Fullscreen",
                "locale",
                "language",
                "Language",
                "resolution_width",
                "resolutionWidth",
                "ResolutionWidth",
                "resolution_height",
                "resolutionHeight",
                "ResolutionHeight",
                "window_mode",
                "windowMode",
                "WindowMode",
                "developer_mode_enabled",
                "developerModeEnabled",
                "DeveloperModeEnabled",
                "key_bindings",
                "keyBindings",
                "KeyBindings",
            };

            foreach (var key in knownAliases)
            {
                payload.Remove(key);
            }
        }

        private static void ApplyCanonicalSettingsPayload(
            Dictionary<string, object?> payload,
            SettingsSaveData settings
        )
        {
            payload["masterVolume"] = settings.MasterVolume;
            payload["musicVolume"] = settings.MusicVolume;
            payload["sfxVolume"] = settings.SFXVolume;
            payload["uiVolume"] = settings.UiVolume;
            payload["mouseSensitivity"] = settings.MouseSensitivity;
            payload["crosshairSize"] = settings.CrosshairSize;
            payload["crosshairAlpha"] = settings.CrosshairAlpha;
            payload["showCenterDot"] = settings.ShowCenterDot;
            payload["centerDotSize"] = settings.CenterDotSize;
            payload["spreadIncreasePerShot"] = settings.SpreadIncreasePerShot;
            payload["crosshairRecoveryRate"] = settings.CrosshairRecoveryRate;
            payload["maxSpreadMultiplier"] = settings.MaxSpreadMultiplier;
            payload["invertMouseY"] = settings.InvertMouseY;
            payload["showDamageNumbers"] = settings.ShowDamageNumbers;
            payload["screenShake"] = settings.ScreenShake;
            payload["targetFrameRate"] = settings.TargetFrameRate;
            payload["vSync"] = settings.VSync;
            payload["fullscreen"] = settings.Fullscreen;
            payload["language"] = settings.Language;
            payload["resolutionWidth"] = settings.ResolutionWidth;
            payload["resolutionHeight"] = settings.ResolutionHeight;
            payload["windowMode"] = (int)settings.WindowMode;
            payload["developerModeEnabled"] = settings.DeveloperModeEnabled;
            payload["keyBindings"] = settings.KeyBindings;
        }

        private SettingsSaveData MergeSettingsFromDictionary(
            SettingsSaveData baseSettings,
            Godot.Collections.Dictionary changes
        )
        {
            var merged = new SettingsSaveData
            {
                MasterVolume = baseSettings.MasterVolume,
                MusicVolume = baseSettings.MusicVolume,
                SFXVolume = baseSettings.SFXVolume,
                UiVolume = baseSettings.UiVolume,
                MouseSensitivity = baseSettings.MouseSensitivity,
                CrosshairSize = baseSettings.CrosshairSize,
                CrosshairAlpha = baseSettings.CrosshairAlpha,
                ShowCenterDot = baseSettings.ShowCenterDot,
                CenterDotSize = baseSettings.CenterDotSize,
                SpreadIncreasePerShot = baseSettings.SpreadIncreasePerShot,
                CrosshairRecoveryRate = baseSettings.CrosshairRecoveryRate,
                MaxSpreadMultiplier = baseSettings.MaxSpreadMultiplier,
                InvertMouseY = baseSettings.InvertMouseY,
                ShowDamageNumbers = baseSettings.ShowDamageNumbers,
                ScreenShake = baseSettings.ScreenShake,
                TargetFrameRate = baseSettings.TargetFrameRate,
                VSync = baseSettings.VSync,
                Fullscreen = baseSettings.Fullscreen,
                Language = baseSettings.Language,
                ResolutionWidth = baseSettings.ResolutionWidth,
                ResolutionHeight = baseSettings.ResolutionHeight,
                WindowMode = baseSettings.WindowMode,
                DeveloperModeEnabled = baseSettings.DeveloperModeEnabled,
                KeyBindings = new Dictionary<string, string>(baseSettings.KeyBindings),
            };

            merged.MasterVolume = ReadFloatFromChanges(changes, merged.MasterVolume, "master_volume", "masterVolume");
            merged.MusicVolume = ReadFloatFromChanges(changes, merged.MusicVolume, "music_volume", "musicVolume");
            merged.SFXVolume = ReadFloatFromChanges(changes, merged.SFXVolume, "sfx_volume", "sfxVolume");
            merged.UiVolume = ReadFloatFromChanges(changes, merged.UiVolume, "ui_volume", "uiVolume", "UiVolume");
            merged.MouseSensitivity = ReadFloatFromChanges(
                changes,
                merged.MouseSensitivity,
                "mouse_sensitivity",
                "mouseSensitivity"
            );
            merged.CrosshairSize = ReadFloatFromChanges(
                changes,
                merged.CrosshairSize,
                "crosshair_size",
                "crosshairSize"
            );
            merged.CrosshairAlpha = ReadFloatFromChanges(
                changes,
                merged.CrosshairAlpha,
                "crosshair_alpha",
                "crosshairAlpha"
            );
            merged.ShowCenterDot = ReadBoolFromChanges(
                changes,
                merged.ShowCenterDot,
                "show_center_dot",
                "showCenterDot"
            );
            merged.CenterDotSize = ReadFloatFromChanges(
                changes,
                merged.CenterDotSize,
                "center_dot_size",
                "centerDotSize"
            );
            merged.SpreadIncreasePerShot = ReadFloatFromChanges(
                changes,
                merged.SpreadIncreasePerShot,
                "spread_increase_per_shot",
                "spreadIncreasePerShot"
            );
            merged.CrosshairRecoveryRate = ReadFloatFromChanges(
                changes,
                merged.CrosshairRecoveryRate,
                "crosshair_recovery_rate",
                "crosshairRecoveryRate"
            );
            merged.MaxSpreadMultiplier = ReadFloatFromChanges(
                changes,
                merged.MaxSpreadMultiplier,
                "max_spread_multiplier",
                "maxSpreadMultiplier"
            );
            merged.InvertMouseY = ReadBoolFromChanges(changes, merged.InvertMouseY, "invert_mouse_y", "invertMouseY");
            merged.ShowDamageNumbers = ReadBoolFromChanges(
                changes,
                merged.ShowDamageNumbers,
                "show_damage_numbers",
                "showDamageNumbers"
            );
            merged.ScreenShake = ReadBoolFromChanges(changes, merged.ScreenShake, "screen_shake", "screenShake");
            merged.TargetFrameRate = ReadIntFromChanges(
                changes,
                merged.TargetFrameRate,
                "target_frame_rate",
                "targetFrameRate"
            );
            merged.Fullscreen = ReadBoolFromChanges(changes, merged.Fullscreen, "fullscreen");
            merged.VSync = ReadBoolFromChanges(changes, merged.VSync, "vsync", "vSync");

            merged.WindowMode = (WindowMode)ReadIntFromChanges(
                changes,
                (int)merged.WindowMode,
                "window_mode",
                "windowMode"
            );

            merged.Language = ReadStringFromChanges(changes, merged.Language, "locale", "language");

            merged.DeveloperModeEnabled = ReadBoolFromChanges(
                changes,
                merged.DeveloperModeEnabled,
                "developer_mode_enabled",
                "developerModeEnabled"
            );

            merged.ResolutionWidth = ReadIntFromChanges(
                changes,
                merged.ResolutionWidth,
                "resolution_width",
                "resolutionWidth"
            );

            merged.ResolutionHeight = ReadIntFromChanges(
                changes,
                merged.ResolutionHeight,
                "resolution_height",
                "resolutionHeight"
            );

            return merged;
        }

        private static float ReadFloatFromChanges(
            Godot.Collections.Dictionary changes,
            float fallback,
            params string[] keys
        )
        {
            foreach (var key in keys)
            {
                if (TryGetDictionaryValue(changes, key, out var value))
                {
                    return ConvertToFloat(value, fallback);
                }
            }

            return fallback;
        }

        private static int ReadIntFromChanges(Godot.Collections.Dictionary changes, int fallback, params string[] keys)
        {
            foreach (var key in keys)
            {
                if (TryGetDictionaryValue(changes, key, out var value))
                {
                    return ConvertToInt(value, fallback);
                }
            }

            return fallback;
        }

        private static bool ReadBoolFromChanges(
            Godot.Collections.Dictionary changes,
            bool fallback,
            params string[] keys
        )
        {
            foreach (var key in keys)
            {
                if (TryGetDictionaryValue(changes, key, out var value))
                {
                    return ConvertToBool(value, fallback);
                }
            }

            return fallback;
        }

        private static string ReadStringFromChanges(
            Godot.Collections.Dictionary changes,
            string fallback,
            params string[] keys
        )
        {
            foreach (var key in keys)
            {
                if (TryGetDictionaryValue(changes, key, out var value))
                {
                    return ConvertToStringValue(value, fallback);
                }
            }

            return fallback;
        }

        private static bool TryGetDictionaryValue(Godot.Collections.Dictionary changes, string key, out object? value)
        {
            value = null;
            if (!changes.ContainsKey(key))
            {
                return false;
            }

            value = changes[key];
            return true;
        }

        private static float ConvertToFloat(object? value, float fallback)
        {
            var normalized = NormalizeGodotValue(value);
            if (normalized == null)
            {
                return fallback;
            }

            if (normalized is float f)
                return f;
            if (normalized is double d)
                return (float)d;
            if (normalized is int i)
                return i;
            if (normalized is long l)
                return l;
            if (normalized is JsonElement element)
            {
                if (element.ValueKind == JsonValueKind.Number)
                    return element.GetSingle();
                if (
                    element.ValueKind == JsonValueKind.String
                    && float.TryParse(
                        element.GetString(),
                        NumberStyles.Float,
                        CultureInfo.InvariantCulture,
                        out var parsed
                    )
                )
                    return parsed;
                return fallback;
            }
            if (
                normalized is string text
                && float.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out var parsedFloat)
            )
                return parsedFloat;

            try
            {
                return Convert.ToSingle(normalized, CultureInfo.InvariantCulture);
            }
            catch (Exception)
            {
                return fallback;
            }
        }

        private static int ConvertToInt(object? value, int fallback)
        {
            var normalized = NormalizeGodotValue(value);
            if (normalized == null)
            {
                return fallback;
            }

            if (normalized is int i)
                return i;
            if (normalized is long l)
                return (int)l;
            if (normalized is float f)
                return (int)f;
            if (normalized is double d)
                return (int)d;
            if (normalized is JsonElement element)
            {
                if (element.ValueKind == JsonValueKind.Number)
                {
                    if (element.TryGetInt32(out var intValue))
                        return intValue;
                    if (element.TryGetDouble(out var doubleValue))
                        return (int)doubleValue;
                }
                if (element.ValueKind == JsonValueKind.String && int.TryParse(element.GetString(), out var parsed))
                    return parsed;
                return fallback;
            }
            if (normalized is string text && int.TryParse(text, out var parsedInt))
                return parsedInt;

            try
            {
                return Convert.ToInt32(normalized, CultureInfo.InvariantCulture);
            }
            catch (Exception)
            {
                return fallback;
            }
        }

        private static bool ConvertToBool(object? value, bool fallback)
        {
            var normalized = NormalizeGodotValue(value);
            if (normalized == null)
            {
                return fallback;
            }

            if (normalized is bool b)
                return b;
            if (normalized is int i)
                return i != 0;
            if (normalized is long l)
                return l != 0;
            if (normalized is float f)
                return !Mathf.IsZeroApprox(f);
            if (normalized is double d)
                return Math.Abs(d) > double.Epsilon;
            if (normalized is JsonElement element)
            {
                if (element.ValueKind == JsonValueKind.True)
                    return true;
                if (element.ValueKind == JsonValueKind.False)
                    return false;
                if (element.ValueKind == JsonValueKind.Number)
                {
                    if (element.TryGetInt32(out var intValue))
                        return intValue != 0;
                    if (element.TryGetDouble(out var doubleValue))
                        return Math.Abs(doubleValue) > double.Epsilon;
                }
                if (element.ValueKind == JsonValueKind.String && bool.TryParse(element.GetString(), out var parsed))
                    return parsed;
                return fallback;
            }
            if (normalized is string text)
            {
                if (bool.TryParse(text, out var parsedBool))
                    return parsedBool;
                if (int.TryParse(text, out var parsedInt))
                    return parsedInt != 0;
                return fallback;
            }

            try
            {
                return Convert.ToBoolean(normalized, CultureInfo.InvariantCulture);
            }
            catch (Exception)
            {
                return fallback;
            }
        }

        private static string ConvertToStringValue(object? value, string fallback)
        {
            var normalized = NormalizeGodotValue(value);
            if (normalized == null)
            {
                return fallback;
            }

            if (normalized is JsonElement element)
            {
                if (element.ValueKind == JsonValueKind.String)
                {
                    return element.GetString() ?? fallback;
                }

                return fallback;
            }

            return Convert.ToString(normalized, CultureInfo.InvariantCulture) ?? fallback;
        }

        private static object? NormalizeGodotValue(object? value)
        {
            if (value == null)
            {
                return null;
            }

            var valueType = value.GetType();
            if (valueType.FullName != "Godot.Variant")
            {
                return value;
            }

            var objProperty = valueType.GetProperty("Obj");
            return objProperty?.GetValue(value);
        }

        private SettingsSaveData ParseSettingsElement(JsonElement root, SettingsSaveData defaults)
        {
            var parsed = new SettingsSaveData
            {
                MasterVolume = ReadFloat(
                    root,
                    new[] { "master_volume", "masterVolume", "MasterVolume" },
                    defaults.MasterVolume
                ),
                MusicVolume = ReadFloat(
                    root,
                    new[] { "music_volume", "musicVolume", "MusicVolume" },
                    defaults.MusicVolume
                ),
                SFXVolume = ReadFloat(root, new[] { "sfx_volume", "sfxVolume", "SFXVolume" }, defaults.SFXVolume),
                UiVolume = ReadFloat(
                    root,
                    new[] { "ui_volume", "uiVolume", "UiVolume", "UIVolume" },
                    defaults.UiVolume
                ),
                MouseSensitivity = ReadFloat(
                    root,
                    new[] { "mouse_sensitivity", "mouseSensitivity", "MouseSensitivity" },
                    defaults.MouseSensitivity
                ),
                CrosshairSize = ReadFloat(
                    root,
                    new[] { "crosshair_size", "crosshairSize", "CrosshairSize" },
                    defaults.CrosshairSize
                ),
                CrosshairAlpha = ReadFloat(
                    root,
                    new[] { "crosshair_alpha", "crosshairAlpha", "CrosshairAlpha" },
                    defaults.CrosshairAlpha
                ),
                ShowCenterDot = ReadBool(
                    root,
                    new[] { "show_center_dot", "showCenterDot", "ShowCenterDot" },
                    defaults.ShowCenterDot
                ),
                CenterDotSize = ReadFloat(
                    root,
                    new[] { "center_dot_size", "centerDotSize", "CenterDotSize" },
                    defaults.CenterDotSize
                ),
                SpreadIncreasePerShot = ReadFloat(
                    root,
                    new[] { "spread_increase_per_shot", "spreadIncreasePerShot", "SpreadIncreasePerShot" },
                    defaults.SpreadIncreasePerShot
                ),
                CrosshairRecoveryRate = ReadFloat(
                    root,
                    new[] { "crosshair_recovery_rate", "crosshairRecoveryRate", "CrosshairRecoveryRate" },
                    defaults.CrosshairRecoveryRate
                ),
                MaxSpreadMultiplier = ReadFloat(
                    root,
                    new[] { "max_spread_multiplier", "maxSpreadMultiplier", "MaxSpreadMultiplier" },
                    defaults.MaxSpreadMultiplier
                ),
                InvertMouseY = ReadBool(
                    root,
                    new[] { "invert_mouse_y", "invertMouseY", "InvertMouseY" },
                    defaults.InvertMouseY
                ),
                ShowDamageNumbers = ReadBool(
                    root,
                    new[] { "show_damage_numbers", "showDamageNumbers", "ShowDamageNumbers" },
                    defaults.ShowDamageNumbers
                ),
                ScreenShake = ReadBool(
                    root,
                    new[] { "screen_shake", "screenShake", "ScreenShake" },
                    defaults.ScreenShake
                ),
                TargetFrameRate = ReadInt(
                    root,
                    new[] { "target_frame_rate", "targetFrameRate", "TargetFrameRate" },
                    defaults.TargetFrameRate
                ),
                VSync = ReadBool(root, new[] { "vsync", "vSync", "VSync" }, defaults.VSync),
                Fullscreen = ReadBool(root, new[] { "fullscreen", "Fullscreen" }, defaults.Fullscreen),
                Language = ReadString(root, new[] { "locale", "language", "Language" }, defaults.Language),
                ResolutionWidth = ReadInt(
                    root,
                    new[] { "resolution_width", "resolutionWidth", "ResolutionWidth" },
                    defaults.ResolutionWidth
                ),
                ResolutionHeight = ReadInt(
                    root,
                    new[] { "resolution_height", "resolutionHeight", "ResolutionHeight" },
                    defaults.ResolutionHeight
                ),
                WindowMode = (WindowMode)ReadInt(
                    root,
                    new[] { "window_mode", "windowMode", "WindowMode" },
                    (int)defaults.WindowMode
                ),
                DeveloperModeEnabled = ReadBool(
                    root,
                    new[] { "developer_mode_enabled", "developerModeEnabled", "DeveloperModeEnabled" },
                    defaults.DeveloperModeEnabled
                ),
                KeyBindings = new Dictionary<string, string>(defaults.KeyBindings),
            };

            if (
                root.TryGetProperty("keyBindings", out var keyBindingsElement)
                && keyBindingsElement.ValueKind == JsonValueKind.Object
            )
            {
                parsed.KeyBindings = ReadStringDictionary(keyBindingsElement);
            }
            else if (
                root.TryGetProperty("key_bindings", out var keyBindingsLegacy)
                && keyBindingsLegacy.ValueKind == JsonValueKind.Object
            )
            {
                parsed.KeyBindings = ReadStringDictionary(keyBindingsLegacy);
            }

            return parsed;
        }

        private Godot.Collections.Dictionary ToGDScriptSettingsDictionary(SettingsSaveData settings)
        {
            return new Godot.Collections.Dictionary
            {
                ["master_volume"] = settings.MasterVolume,
                ["music_volume"] = settings.MusicVolume,
                ["sfx_volume"] = settings.SFXVolume,
                ["ui_volume"] = settings.UiVolume,
                ["mouse_sensitivity"] = settings.MouseSensitivity,
                ["crosshair_size"] = settings.CrosshairSize,
                ["crosshair_alpha"] = settings.CrosshairAlpha,
                ["show_center_dot"] = settings.ShowCenterDot,
                ["center_dot_size"] = settings.CenterDotSize,
                ["spread_increase_per_shot"] = settings.SpreadIncreasePerShot,
                ["crosshair_recovery_rate"] = settings.CrosshairRecoveryRate,
                ["max_spread_multiplier"] = settings.MaxSpreadMultiplier,
                ["fullscreen"] = settings.Fullscreen,
                ["vsync"] = settings.VSync,
                ["window_mode"] = (int)settings.WindowMode,
                ["locale"] = settings.Language,
                ["developer_mode_enabled"] = settings.DeveloperModeEnabled,
                ["resolution_width"] = settings.ResolutionWidth,
                ["resolution_height"] = settings.ResolutionHeight,
            };
        }

        private static float ReadFloat(JsonElement root, IEnumerable<string> keys, float fallback)
        {
            foreach (var key in keys)
            {
                if (root.TryGetProperty(key, out var element))
                {
                    if (element.ValueKind == JsonValueKind.Number)
                        return element.GetSingle();
                    if (
                        element.ValueKind == JsonValueKind.String
                        && float.TryParse(element.GetString(), out var parsed)
                    )
                        return parsed;
                }
            }

            return fallback;
        }

        private static int ReadInt(JsonElement root, IEnumerable<string> keys, int fallback)
        {
            foreach (var key in keys)
            {
                if (root.TryGetProperty(key, out var element))
                {
                    if (element.ValueKind == JsonValueKind.Number)
                    {
                        if (element.TryGetInt32(out var intValue))
                        {
                            return intValue;
                        }

                        if (element.TryGetDouble(out var doubleValue))
                        {
                            return Convert.ToInt32(Math.Round(doubleValue, MidpointRounding.AwayFromZero));
                        }
                    }

                    if (element.ValueKind == JsonValueKind.String && int.TryParse(element.GetString(), out var parsed))
                        return parsed;

                    if (element.ValueKind == JsonValueKind.String)
                    {
                        var raw = element.GetString();
                        if (
                            double.TryParse(raw, NumberStyles.Float, CultureInfo.InvariantCulture, out var parsedDouble)
                        )
                        {
                            return Convert.ToInt32(Math.Round(parsedDouble, MidpointRounding.AwayFromZero));
                        }
                    }
                }
            }

            return fallback;
        }

        private static bool ReadBool(JsonElement root, IEnumerable<string> keys, bool fallback)
        {
            foreach (var key in keys)
            {
                if (root.TryGetProperty(key, out var element))
                {
                    if (element.ValueKind == JsonValueKind.True)
                        return true;
                    if (element.ValueKind == JsonValueKind.False)
                        return false;
                    if (element.ValueKind == JsonValueKind.String && bool.TryParse(element.GetString(), out var parsed))
                        return parsed;
                }
            }

            return fallback;
        }

        private static string ReadString(JsonElement root, IEnumerable<string> keys, string fallback)
        {
            foreach (var key in keys)
            {
                if (root.TryGetProperty(key, out var element) && element.ValueKind == JsonValueKind.String)
                {
                    return element.GetString() ?? fallback;
                }
            }

            return fallback;
        }

        private static Dictionary<string, string> ReadStringDictionary(JsonElement root)
        {
            var result = new Dictionary<string, string>();
            foreach (var property in root.EnumerateObject())
            {
                if (property.Value.ValueKind == JsonValueKind.String)
                {
                    result[property.Name] = property.Value.GetString() ?? string.Empty;
                }
            }

            return result;
        }

        /// <summary>
        /// 应用窗口分辨率
        /// </summary>
        /// <param name="width">窗口宽度</param>
        /// <param name="height">窗口高度</param>
        public void ApplyResolution(int width, int height)
        {
            try
            {
                DisplayServer.WindowSetSize(new Vector2I(width, height));
                GD.Print($"Resolution applied: {width}x{height}");
            }
            catch (Exception ex)
            {
                GD.PushError($"Failed to apply resolution: {ex.Message}");
            }
        }

        /// <summary>
        /// 应用窗口模式
        /// </summary>
        /// <param name="mode">窗口模式: 0=窗口化, 1=全屏, 2=无边框全屏</param>
        public void ApplyWindowMode(int mode)
        {
            try
            {
                DisplayServer.WindowMode windowMode = mode switch
                {
                    0 => DisplayServer.WindowMode.Windowed,
                    1 => DisplayServer.WindowMode.Fullscreen,
                    2 => DisplayServer.WindowMode.ExclusiveFullscreen,
                    _ => DisplayServer.WindowMode.Windowed,
                };

                DisplayServer.WindowSetMode(windowMode);
                GD.Print($"Window mode applied: {windowMode}");
            }
            catch (Exception ex)
            {
                GD.PushError($"Failed to apply window mode: {ex.Message}");
            }
        }

        /// <summary>
        /// 应用主音量
        /// </summary>
        /// <param name="volume">音量值 (0.0 - 1.0 线性)</param>
        public void ApplyVolume(float volume)
        {
            try
            {
                // 将线性音量转换为分贝
                float volumeDb = Mathf.LinearToDb(volume);
                AudioServer.SetBusVolumeDb(0, volumeDb);
                GD.Print($"Master volume applied: {volume} (linear) = {volumeDb} dB");
            }
            catch (Exception ex)
            {
                GD.PushError($"Failed to apply volume: {ex.Message}");
            }
        }
        #endregion

        #region Private Methods
        private void EnsureSaveDirectory()
        {
            if (!DirAccess.DirExistsAbsolute(SAVE_FOLDER))
            {
                DirAccess.MakeDirRecursiveAbsolute(SAVE_FOLDER);
            }
        }

        private string GetSaveFilePath(int slot)
        {
            return $"{SAVE_FOLDER}save_{slot:D2}{SAVE_EXTENSION}";
        }

        private string GetBackupFilePath(int slot, int backupIndex)
        {
            return $"{SAVE_FOLDER}save_{slot:D2}_{backupIndex}{BACKUP_EXTENSION}";
        }

        private void CreateBackup(int slot)
        {
            string mainPath = GetSaveFilePath(slot);

            if (!FileAccess.FileExists(mainPath))
            {
                return;
            }

            // 移动现有备份
            for (int i = MAX_BACKUP_COUNT; i > 1; i--)
            {
                string oldPath = GetBackupFilePath(slot, i - 1);
                string newPath = GetBackupFilePath(slot, i);

                if (FileAccess.FileExists(oldPath))
                {
                    if (FileAccess.FileExists(newPath))
                    {
                        DirAccess.RemoveAbsolute(newPath);
                    }
                    DirAccess.RenameAbsolute(oldPath, newPath);
                }
            }

            // 创建新备份
            string backupPath = GetBackupFilePath(slot, 1);
            DirAccess.RenameAbsolute(mainPath, backupPath);
        }

        private void UpdateSaveData()
        {
            if (_currentSaveData == null)
                return;

            // 更新玩家数据
            if (_cachedPlayerData != null)
            {
                _currentSaveData.Player = ConvertToSaveData(_cachedPlayerData);
            }

            // 更新游戏时间
            if (GameStateManager.Instance != null)
            {
                _currentSaveData.Player.TotalPlayTime += (int)GameStateManager.Instance.StateTime;
            }
        }

        private void ApplySaveData()
        {
            if (_currentSaveData == null)
                return;

            // 转换并缓存玩家数据
            _cachedPlayerData = ConvertToPlayerData(_currentSaveData.Player);

            // 应用设置
            // TODO: 应用游戏设置
        }

        private PlayerSaveData ConvertToSaveData(PlayerData playerData)
        {
            return new PlayerSaveData
            {
                PlayerName = playerData.PlayerName,
                Level = playerData.Level,
                Experience = playerData.Experience,
                Gold = playerData.Gold,
                Gems = playerData.Gems,
                TotalPlayTime = playerData.TotalPlayTime,
                UnlockedWeapons = new System.Collections.Generic.List<string>(playerData.UnlockedWeapons),
                CompletedLevels = new System.Collections.Generic.List<string>(playerData.CompletedLevels),
                WeaponKills = new System.Collections.Generic.Dictionary<string, int>(playerData.WeaponKills),
                Stats = new PlayerStatsSaveData
                {
                    TotalKills = playerData.Stats.TotalKills,
                    TotalDeaths = playerData.Stats.TotalDeaths,
                    ShotsFired = playerData.Stats.ShotsFired,
                    ShotsHit = playerData.Stats.ShotsHit,
                    TotalDamageDealt = playerData.Stats.TotalDamageDealt,
                    TotalDamageTaken = playerData.Stats.TotalDamageTaken,
                    MissionsCompleted = playerData.Stats.MissionsCompleted,
                    MissionsFailed = playerData.Stats.MissionsFailed,
                },
            };
        }

        private PlayerData ConvertToPlayerData(PlayerSaveData saveData)
        {
            var playerData = new PlayerData
            {
                PlayerName = saveData.PlayerName,
                Level = saveData.Level,
                Experience = saveData.Experience,
                Gold = saveData.Gold,
                Gems = saveData.Gems,
                TotalPlayTime = saveData.TotalPlayTime,
                UnlockedWeapons = new System.Collections.Generic.List<string>(saveData.UnlockedWeapons),
                CompletedLevels = new System.Collections.Generic.List<string>(saveData.CompletedLevels),
                WeaponKills = new System.Collections.Generic.Dictionary<string, int>(saveData.WeaponKills),
                Stats = new PlayerStats
                {
                    TotalKills = saveData.Stats.TotalKills,
                    TotalDeaths = saveData.Stats.TotalDeaths,
                    ShotsFired = saveData.Stats.ShotsFired,
                    ShotsHit = saveData.Stats.ShotsHit,
                    TotalDamageDealt = saveData.Stats.TotalDamageDealt,
                    TotalDamageTaken = saveData.Stats.TotalDamageTaken,
                    MissionsCompleted = saveData.Stats.MissionsCompleted,
                    MissionsFailed = saveData.Stats.MissionsFailed,
                },
            };

            return playerData;
        }

        private void ProcessSaveQueue()
        {
            if (_isSaving || _saveQueue.Count == 0)
                return;

            var operation = _saveQueue.Dequeue();
            SaveToSlot(operation.Slot, operation.ShowNotification);
        }
        #endregion

        #region Utility
        /// <summary>
        /// 导出存档到指定路径
        /// </summary>
        public bool ExportSave(int slot, string exportPath)
        {
            string sourcePath = GetSaveFilePath(slot);

            if (!FileAccess.FileExists(sourcePath))
            {
                return false;
            }

            try
            {
                using var source = FileAccess.Open(sourcePath, FileAccess.ModeFlags.Read);
                using var dest = FileAccess.Open(exportPath, FileAccess.ModeFlags.Write);

                if (source != null && dest != null)
                {
                    dest.StoreString(source.GetAsText());
                    return true;
                }
            }
            catch (Exception ex)
            {
                GD.PushError($"Failed to export save: {ex.Message}");
            }

            return false;
        }

        /// <summary>
        /// 从指定路径导入存档
        /// </summary>
        public bool ImportSave(string importPath, int targetSlot)
        {
            if (!FileAccess.FileExists(importPath))
            {
                return false;
            }

            try
            {
                using var source = FileAccess.Open(importPath, FileAccess.ModeFlags.Read);
                string json = source.GetAsText();

                // 验证存档数据
                var saveData = SaveSerializer.Deserialize(json);
                if (saveData == null || !SaveSerializer.Validate(saveData))
                {
                    GD.PushError("Invalid save file format");
                    return false;
                }

                // 更新槽位索引
                saveData.SlotIndex = targetSlot;
                json = SaveSerializer.Serialize(saveData);

                // 保存到目标槽位
                string targetPath = GetSaveFilePath(targetSlot);
                using var dest = FileAccess.Open(targetPath, FileAccess.ModeFlags.Write);
                if (dest != null)
                {
                    dest.StoreString(json);
                    GD.Print($"Save imported to slot {targetSlot}");
                    return true;
                }
            }
            catch (Exception ex)
            {
                GD.PushError($"Failed to import save: {ex.Message}");
            }

            return false;
        }
        #endregion

        #region Inner Classes
        private class SaveOperation
        {
            public int Slot { get; set; }
            public bool ShowNotification { get; set; }
        }
        #endregion
    }
}
