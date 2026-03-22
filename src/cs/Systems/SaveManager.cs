using System;
using System.Collections.Generic;
using System.Linq;
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
        /// 保存游戏设置
        /// </summary>
        public void SaveSettings(SettingsSaveData settings)
        {
            try
            {
                // 使用JSON序列化设置
                var dict = new Godot.Collections.Dictionary
                {
                    ["masterVolume"] = settings.MasterVolume,
                    ["musicVolume"] = settings.MusicVolume,
                    ["sfxVolume"] = settings.SFXVolume,
                    ["mouseSensitivity"] = settings.MouseSensitivity,
                    ["invertMouseY"] = settings.InvertMouseY,
                    ["showDamageNumbers"] = settings.ShowDamageNumbers,
                    ["screenShake"] = settings.ScreenShake,
                    ["targetFrameRate"] = settings.TargetFrameRate,
                    ["vsync"] = settings.VSync,
                    ["fullscreen"] = settings.Fullscreen,
                    ["language"] = settings.Language,
                };

                string json = dict.ToString();
                using var file = FileAccess.Open(SETTINGS_FILE, FileAccess.ModeFlags.Write);
                if (file != null)
                {
                    file.StoreString(json);
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
            var settings = new SettingsSaveData();

            if (!FileAccess.FileExists(SETTINGS_FILE))
            {
                return settings;
            }

            try
            {
                using var file = FileAccess.Open(SETTINGS_FILE, FileAccess.ModeFlags.Read);
                if (file != null)
                {
                    string json = file.GetAsText();
                    // 解析JSON并填充设置
                    // 这里简化处理，实际应使用JSON解析器
                }
            }
            catch (Exception ex)
            {
                GD.PushError($"Failed to load settings: {ex.Message}");
            }

            return settings;
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
