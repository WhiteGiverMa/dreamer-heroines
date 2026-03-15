using Godot;
using System;
using System.Collections.Generic;

namespace StrikeForceLike.Systems
{
    /// <summary>
    /// 游戏状态枚举
    /// </summary>
    public enum GameState
    {
        None,           // 无状态/初始化中
        MainMenu,       // 主菜单
        Loading,        // 加载中
        Playing,        // 游戏中
        Paused,         // 暂停
        GameOver,       // 游戏结束
        Victory,        // 胜利
        Cutscene,       // 过场动画
        Shop,           // 商店
        Inventory,      // 背包
        Dialog          // 对话
    }

    /// <summary>
    /// 游戏状态管理器 - 单例模式
    /// 管理游戏整体状态，处理状态转换，跨场景持久化
    /// </summary>
    public partial class GameStateManager : Node
    {
        #region Singleton
        private static GameStateManager? _instance;
        public static GameStateManager Instance
        {
            get
            {
                if (_instance == null)
                {
                    GD.PushWarning("GameStateManager instance is null! Make sure it's added to autoload.");
                }
                return _instance!;
            }
        }
        #endregion

        #region Fields
        private GameState _currentState = GameState.None;
        private GameState _previousState = GameState.None;
        private readonly Stack<GameState> _stateHistory = new Stack<GameState>();
        private readonly Dictionary<GameState, List<Action>> _stateEnterCallbacks = new Dictionary<GameState, List<Action>>();
        private readonly Dictionary<GameState, List<Action>> _stateExitCallbacks = new Dictionary<GameState, List<Action>>();
        private readonly Dictionary<string, object> _stateData = new Dictionary<string, object>();

        private bool _isTransitioning = false;
        private double _stateTimer = 0.0;
        private int _currentLevel = 1;
        private int _currentDifficulty = 1;
        private string _currentScenePath = "";
        #endregion

        #region Properties
        /// <summary>
        /// 当前游戏状态
        /// </summary>
        public GameState CurrentState => _currentState;

        /// <summary>
        /// 上一个游戏状态
        /// </summary>
        public GameState PreviousState => _previousState;

        /// <summary>
        /// 是否正在状态转换中
        /// </summary>
        public bool IsTransitioning => _isTransitioning;

        /// <summary>
        /// 当前状态持续时间
        /// </summary>
        public double StateTime => _stateTimer;

        /// <summary>
        /// 当前关卡编号
        /// </summary>
        public int CurrentLevel
        {
            get => _currentLevel;
            set
            {
                if (_currentLevel != value)
                {
                    _currentLevel = value;
                    EmitSignal(SignalName.LevelChanged, _currentLevel);
                }
            }
        }

        /// <summary>
        /// 当前难度等级（0-4）
        /// </summary>
        public int CurrentDifficulty
        {
            get => _currentDifficulty;
            set
            {
                value = Mathf.Clamp(value, 0, 4);
                if (_currentDifficulty != value)
                {
                    _currentDifficulty = value;
                    EmitSignal(SignalName.DifficultyChanged, _currentDifficulty);
                }
            }
        }

        /// <summary>
        /// 当前场景路径
        /// </summary>
        public string CurrentScenePath
        {
            get => _currentScenePath;
            set => _currentScenePath = value;
        }

        /// <summary>
        /// 是否处于游戏状态
        /// </summary>
        public bool IsPlaying => _currentState == GameState.Playing;

        /// <summary>
        /// 是否处于暂停状态
        /// </summary>
        public bool IsPaused => _currentState == GameState.Paused;

        /// <summary>
        /// 是否可以暂停
        /// </summary>
        public bool CanPause => _currentState == GameState.Playing || _currentState == GameState.Shop;
        #endregion

        #region Signals
        [Signal]
        public delegate void StateChangedEventHandler(GameState newState, GameState oldState);

        [Signal]
        public delegate void StateEnterEventHandler(GameState state);

        [Signal]
        public delegate void StateExitEventHandler(GameState state);

        [Signal]
        public delegate void LevelChangedEventHandler(int level);

        [Signal]
        public delegate void DifficultyChangedEventHandler(int difficulty);

        [Signal]
        public delegate void GamePausedEventHandler();

        [Signal]
        public delegate void GameResumedEventHandler();
        #endregion

        #region Godot Lifecycle
        public override void _Ready()
        {
            if (_instance != null)
            {
                GD.PushWarning("Multiple GameStateManager instances detected! Destroying duplicate.");
                QueueFree();
                return;
            }

            _instance = this;
            ProcessMode = ProcessModeEnum.Always; // 确保在暂停时也能处理

            // 初始化状态回调字典
            foreach (GameState state in Enum.GetValues<GameState>())
            {
                _stateEnterCallbacks[state] = new List<Action>();
                _stateExitCallbacks[state] = new List<Action>();
            }

            GD.Print("GameStateManager initialized");
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
            _stateTimer += delta;
        }

        public override void _Input(InputEvent @event)
        {
            // 处理暂停输入
            if (@event.IsActionPressed("pause") && CanPause)
            {
                TogglePause();
            }
        }
        #endregion

        #region State Management
        /// <summary>
        /// 切换到指定状态
        /// </summary>
        public void ChangeState(GameState newState, bool pushToHistory = true)
        {
            if (_isTransitioning)
            {
                GD.PushWarning($"Cannot change state while transitioning. Current: {_currentState}, Requested: {newState}");
                return;
            }

            if (_currentState == newState)
            {
                return;
            }

            _isTransitioning = true;

            // 保存历史
            if (pushToHistory && _currentState != GameState.None)
            {
                _stateHistory.Push(_currentState);
            }

            // 退出当前状态
            ExitState(_currentState);

            // 更新状态
            _previousState = _currentState;
            _currentState = newState;
            _stateTimer = 0.0;

            GD.Print($"GameState changed: {_previousState} -> {_currentState}");

            // 进入新状态
            EnterState(_currentState);

            // 发送信号
            EmitSignal(SignalName.StateChanged, (int)_currentState, (int)_previousState);

            _isTransitioning = false;
        }

        /// <summary>
        /// 返回上一个状态
        /// </summary>
        public void GoBack()
        {
            if (_stateHistory.Count > 0)
            {
                GameState previousState = _stateHistory.Pop();
                ChangeState(previousState, false);
            }
        }

        /// <summary>
        /// 清除状态历史
        /// </summary>
        public void ClearHistory()
        {
            _stateHistory.Clear();
        }

        /// <summary>
        /// 切换暂停状态
        /// </summary>
        public void TogglePause()
        {
            if (_currentState == GameState.Playing)
            {
                ChangeState(GameState.Paused);
                GetTree().Paused = true;
                EmitSignal(SignalName.GamePaused);
            }
            else if (_currentState == GameState.Paused)
            {
                GetTree().Paused = false;
                ChangeState(GameState.Playing);
                EmitSignal(SignalName.GameResumed);
            }
        }

        /// <summary>
        /// 暂停游戏
        /// </summary>
        public void Pause()
        {
            if (_currentState == GameState.Playing)
            {
                ChangeState(GameState.Paused);
                GetTree().Paused = true;
                EmitSignal(SignalName.GamePaused);
            }
        }

        /// <summary>
        /// 恢复游戏
        /// </summary>
        public void Resume()
        {
            if (_currentState == GameState.Paused)
            {
                GetTree().Paused = false;
                ChangeState(GameState.Playing);
                EmitSignal(SignalName.GameResumed);
            }
        }

        /// <summary>
        /// 开始游戏
        /// </summary>
        public void StartGame(int level = 1, int difficulty = 1)
        {
            CurrentLevel = level;
            CurrentDifficulty = difficulty;
            ClearHistory();
            ChangeState(GameState.Playing);
        }

        /// <summary>
        /// 返回主菜单
        /// </summary>
        public void ReturnToMainMenu()
        {
            GetTree().Paused = false;
            ClearHistory();
            ChangeState(GameState.MainMenu);
        }

        /// <summary>
        /// 游戏结束
        /// </summary>
        public void GameOver()
        {
            ChangeState(GameState.GameOver);
        }

        /// <summary>
        /// 游戏胜利
        /// </summary>
        public void Victory()
        {
            ChangeState(GameState.Victory);
        }

        /// <summary>
        /// 打开商店
        /// </summary>
        public void OpenShop()
        {
            if (_currentState == GameState.Playing)
            {
                ChangeState(GameState.Shop);
            }
        }

        /// <summary>
        /// 关闭商店
        /// </summary>
        public void CloseShop()
        {
            if (_currentState == GameState.Shop)
            {
                GoBack();
            }
        }
        #endregion

        #region State Callbacks
        /// <summary>
        /// 注册状态进入回调
        /// </summary>
        public void RegisterStateEnterCallback(GameState state, Action callback)
        {
            if (_stateEnterCallbacks.TryGetValue(state, out var callbacks))
            {
                callbacks.Add(callback);
            }
        }

        /// <summary>
        /// 注册状态退出回调
        /// </summary>
        public void RegisterStateExitCallback(GameState state, Action callback)
        {
            if (_stateExitCallbacks.TryGetValue(state, out var callbacks))
            {
                callbacks.Add(callback);
            }
        }

        /// <summary>
        /// 注销状态进入回调
        /// </summary>
        public void UnregisterStateEnterCallback(GameState state, Action callback)
        {
            if (_stateEnterCallbacks.TryGetValue(state, out var callbacks))
            {
                callbacks.Remove(callback);
            }
        }

        /// <summary>
        /// 注销状态退出回调
        /// </summary>
        public void UnregisterStateExitCallback(GameState state, Action callback)
        {
            if (_stateExitCallbacks.TryGetValue(state, out var callbacks))
            {
                callbacks.Remove(callback);
            }
        }

        private void EnterState(GameState state)
        {
            EmitSignal(SignalName.StateEnter, (int)state);

            if (_stateEnterCallbacks.TryGetValue(state, out var callbacks))
            {
                foreach (var callback in callbacks)
                {
                    try
                    {
                        callback?.Invoke();
                    }
                    catch (Exception ex)
                    {
                        GD.PushError($"Error in state enter callback for {state}: {ex.Message}");
                    }
                }
            }

            // 状态特定处理
            switch (state)
            {
                case GameState.MainMenu:
                    GetTree().Paused = false;
                    break;
                case GameState.Loading:
                    // 加载逻辑
                    break;
                case GameState.Playing:
                    GetTree().Paused = false;
                    break;
                case GameState.Paused:
                    // 暂停逻辑
                    break;
            }
        }

        private void ExitState(GameState state)
        {
            EmitSignal(SignalName.StateExit, (int)state);

            if (_stateExitCallbacks.TryGetValue(state, out var callbacks))
            {
                foreach (var callback in callbacks)
                {
                    try
                                       {
                        callback?.Invoke();
                    }
                    catch (Exception ex)
                    {
                        GD.PushError($"Error in state exit callback for {state}: {ex.Message}");
                    }
                }
            }
        }
        #endregion

        #region State Data
        /// <summary>
        /// 设置状态数据
        /// </summary>
        public void SetStateData<T>(string key, T value)
        {
            _stateData[key] = value!;
        }

        /// <summary>
        /// 获取状态数据
        /// </summary>
        public T? GetStateData<T>(string key, T? defaultValue = default)
        {
            if (_stateData.TryGetValue(key, out var value) && value is T typedValue)
            {
                return typedValue;
            }
            return defaultValue;
        }

        /// <summary>
        /// 检查是否存在状态数据
        /// </summary>
        public bool HasStateData(string key)
        {
            return _stateData.ContainsKey(key);
        }

        /// <summary>
        /// 移除状态数据
        /// </summary>
        public void RemoveStateData(string key)
        {
            _stateData.Remove(key);
        }

        /// <summary>
        /// 清除所有状态数据
        /// </summary>
        public void ClearStateData()
        {
            _stateData.Clear();
        }
        #endregion

        #region Utility
        /// <summary>
        /// 检查当前状态是否匹配
        /// </summary>
        public bool IsInState(GameState state)
        {
            return _currentState == state;
        }

        /// <summary>
        /// 检查当前状态是否匹配任一给定状态
        /// </summary>
        public bool IsInAnyState(params GameState[] states)
        {
            foreach (var state in states)
            {
                if (_currentState == state)
                    return true;
            }
            return false;
        }

        /// <summary>
        /// 获取状态名称
        /// </summary>
        public static string GetStateName(GameState state)
        {
            return state switch
            {
                GameState.None => "None",
                GameState.MainMenu => "Main Menu",
                GameState.Loading => "Loading",
                GameState.Playing => "Playing",
                GameState.Paused => "Paused",
                GameState.GameOver => "Game Over",
                GameState.Victory => "Victory",
                GameState.Cutscene => "Cutscene",
                GameState.Shop => "Shop",
                GameState.Inventory => "Inventory",
                GameState.Dialog => "Dialog",
                _ => "Unknown"
            };
        }

        /// <summary>
        /// 获取状态历史记录
        /// </summary>
        public GameState[] GetStateHistory()
        {
            return _stateHistory.ToArray();
        }
        #endregion
    }
}
