using System;
using Godot;

namespace DreamerHeroines.Examples
{
    /// <summary>
    /// C# 调用 GDScript 示例
    /// 这个类展示了如何从 C# 调用 GDScript 的方法和访问 GDScript 节点
    /// </summary>
    public partial class CSharpToGdScript : Node
    {
        #region Fields
        private Node? _gameManager;
        private Node? _audioManager;
        private Node? _inputManager;
        #endregion

        #region Godot Lifecycle
        public override void _Ready()
        {
            // 获取 GDScript 自动加载节点
            _gameManager = GetNode("/root/GameManager");
            _audioManager = GetNode("/root/AudioManager");
            _inputManager = GetNode("/root/InputManager");

            if (_gameManager == null)
            {
                GD.PushWarning("[C#] GameManager not found! Make sure it's added to autoload.");
            }

            GD.Print("[C#] CSharpToGdScript initialized");
        }
        #endregion

        #region Calling GDScript Methods

        /// <summary>
        /// 示例：调用 GDScript 的 GameManager 方法
        /// </summary>
        public void CallGameManagerMethod(string methodName, params Variant[] args)
        {
            if (_gameManager == null)
            {
                GD.PushError("[C#] GameManager is null!");
                return;
            }

            try
            {
                // 使用 Call 方法调用 GDScript 函数
                var result = _gameManager.Call(methodName, args);
                GD.Print($"[C#] Called GameManager.{methodName}(), result: {result}");
            }
            catch (Exception ex)
            {
                GD.PushError($"[C#] Error calling GameManager.{methodName}(): {ex.Message}");
            }
        }

        /// <summary>
        /// 示例：调用 GDScript 的 AudioManager 播放音效
        /// </summary>
        public void PlaySound(string soundName)
        {
            if (_audioManager == null)
            {
                GD.PushError("[C#] AudioManager is null!");
                return;
            }

            try
            {
                // 假设 GDScript AudioManager 有 play_sound 方法
                _audioManager.Call("play_sound", soundName);
                GD.Print($"[C#] Called AudioManager.play_sound('{soundName}')");
            }
            catch (Exception ex)
            {
                GD.PushError($"[C#] Error playing sound: {ex.Message}");
            }
        }

        /// <summary>
        /// 示例：调用 GDScript 的 AudioManager 播放音乐
        /// </summary>
        public void PlayMusic(string musicName, bool loop = true)
        {
            if (_audioManager == null)
            {
                GD.PushError("[C#] AudioManager is null!");
                return;
            }

            try
            {
                _audioManager.Call("play_music", musicName, loop);
                GD.Print($"[C#] Called AudioManager.play_music('{musicName}', {loop})");
            }
            catch (Exception ex)
            {
                GD.PushError($"[C#] Error playing music: {ex.Message}");
            }
        }

        /// <summary>
        /// 示例：调用 GDScript 的 AudioManager 停止音乐
        /// </summary>
        public void StopMusic()
        {
            if (_audioManager == null)
                return;

            try
            {
                _audioManager.Call("stop_music");
                GD.Print("[C#] Called AudioManager.stop_music()");
            }
            catch (Exception ex)
            {
                GD.PushError($"[C#] Error stopping music: {ex.Message}");
            }
        }

        /// <summary>
        /// 示例：调用 GDScript 的 InputManager 检查输入
        /// </summary>
        public bool IsActionPressed(string action)
        {
            if (_inputManager == null)
            {
                // 回退到 Godot 内置输入
                return Input.IsActionPressed(action);
            }

            try
            {
                // 假设 GDScript InputManager 有 is_action_pressed 方法
                var result = _inputManager.Call("is_action_pressed", action);
                return result.AsBool();
            }
            catch
            {
                // 回退到 Godot 内置输入
                return Input.IsActionPressed(action);
            }
        }

        /// <summary>
        /// 示例：调用 GDScript 的 InputManager 获取输入向量
        /// </summary>
        public Vector2 GetInputVector()
        {
            if (_inputManager == null)
            {
                // 回退到 Godot 内置输入
                return Input.GetVector("move_left", "move_right", "move_up", "move_down");
            }

            try
            {
                var result = _inputManager.Call("get_input_vector");
                return result.AsVector2();
            }
            catch
            {
                // 回退到 Godot 内置输入
                return Input.GetVector("move_left", "move_right", "move_up", "move_down");
            }
        }

        #endregion

        #region Accessing GDScript Properties

        /// <summary>
        /// 示例：获取 GDScript 节点的属性
        /// </summary>
        public Variant? GetGdScriptProperty(string propertyName)
        {
            if (_gameManager == null)
                return null;

            try
            {
                // 使用 Get 方法获取属性
                return _gameManager.Get(propertyName);
            }
            catch (Exception ex)
            {
                GD.PushError($"[C#] Error getting property '{propertyName}': {ex.Message}");
                return null;
            }
        }

        /// <summary>
        /// 示例：设置 GDScript 节点的属性
        /// </summary>
        public void SetGdScriptProperty(string propertyName, Variant value)
        {
            if (_gameManager == null)
                return;

            try
            {
                // 使用 Set 方法设置属性
                _gameManager.Set(propertyName, value);
                GD.Print($"[C#] Set GameManager.{propertyName} = {value}");
            }
            catch (Exception ex)
            {
                GD.PushError($"[C#] Error setting property '{propertyName}': {ex.Message}");
            }
        }

        /// <summary>
        /// 示例：获取当前关卡
        /// </summary>
        public int GetCurrentLevel()
        {
            var value = GetGdScriptProperty("current_level");
            return value?.AsInt32() ?? 1;
        }

        /// <summary>
        /// 示例：设置当前关卡
        /// </summary>
        public void SetCurrentLevel(int level)
        {
            SetGdScriptProperty("current_level", level);
        }

        /// <summary>
        /// 示例：获取玩家分数
        /// </summary>
        public int GetPlayerScore()
        {
            var value = GetGdScriptProperty("player_score");
            return value?.AsInt32() ?? 0;
        }

        /// <summary>
        /// 示例：设置玩家分数
        /// </summary>
        public void SetPlayerScore(int score)
        {
            SetGdScriptProperty("player_score", score);
        }

        #endregion

        #region Connecting to GDScript Signals

        /// <summary>
        /// 示例：连接 GDScript 信号到 C# 方法
        /// </summary>
        public void ConnectToGdScriptSignal(string signalName, Callable callable)
        {
            if (_gameManager == null)
                return;

            try
            {
                // 连接信号
                _gameManager.Connect(signalName, callable);
                GD.Print($"[C#] Connected to signal: {signalName}");
            }
            catch (Exception ex)
            {
                GD.PushError($"[C#] Error connecting to signal '{signalName}': {ex.Message}");
            }
        }

        /// <summary>
        /// 示例：断开 GDScript 信号连接
        /// </summary>
        public void DisconnectFromGdScriptSignal(string signalName, Callable callable)
        {
            if (_gameManager == null)
                return;

            try
            {
                _gameManager.Disconnect(signalName, callable);
                GD.Print($"[C#] Disconnected from signal: {signalName}");
            }
            catch (Exception ex)
            {
                GD.PushError($"[C#] Error disconnecting from signal '{signalName}': {ex.Message}");
            }
        }

        /// <summary>
        /// 示例：连接常见的游戏信号
        /// </summary>
        public void ConnectCommonSignals()
        {
            // 连接到 GameManager 的信号
            ConnectToGdScriptSignal("level_started", new Callable(this, nameof(OnLevelStarted)));
            ConnectToGdScriptSignal("level_completed", new Callable(this, nameof(OnLevelCompleted)));
            ConnectToGdScriptSignal("player_died", new Callable(this, nameof(OnPlayerDied)));
            ConnectToGdScriptSignal("score_changed", new Callable(this, nameof(OnScoreChanged)));
        }

        // 信号回调方法
        private void OnLevelStarted(int levelNumber)
        {
            GD.Print($"[C#] Level started: {levelNumber}");
        }

        private void OnLevelCompleted(int levelNumber, float completionTime)
        {
            GD.Print($"[C#] Level completed: {levelNumber} in {completionTime}s");
        }

        private void OnPlayerDied(Vector2 deathPosition)
        {
            GD.Print($"[C#] Player died at: {deathPosition}");
        }

        private void OnScoreChanged(int newScore, int delta)
        {
            GD.Print($"[C#] Score changed: {newScore} (delta: {delta})");
        }

        #endregion

        #region Instantiating GDScript Nodes

        /// <summary>
        /// 示例：实例化 GDScript 节点
        /// </summary>
        public Node? InstantiateGdScriptNode(string scriptPath)
        {
            try
            {
                // 加载 GDScript
                var script = GD.Load<GDScript>(scriptPath);
                if (script == null)
                {
                    GD.PushError($"[C#] Failed to load script: {scriptPath}");
                    return null;
                }

                // 创建实例
                var instance = script.New().As<Node>();
                if (instance == null)
                {
                    GD.PushError($"[C#] Failed to instantiate script: {scriptPath}");
                    return null;
                }

                GD.Print($"[C#] Instantiated GDScript node: {scriptPath}");
                return instance;
            }
            catch (Exception ex)
            {
                GD.PushError($"[C#] Error instantiating GDScript node: {ex.Message}");
                return null;
            }
        }

        /// <summary>
        /// 示例：实例化场景中的 GDScript 节点
        /// </summary>
        public Node? InstantiateScene(string scenePath)
        {
            try
            {
                var packedScene = GD.Load<PackedScene>(scenePath);
                if (packedScene == null)
                {
                    GD.PushError($"[C#] Failed to load scene: {scenePath}");
                    return null;
                }

                var instance = packedScene.Instantiate();
                GD.Print($"[C#] Instantiated scene: {scenePath}");
                return instance;
            }
            catch (Exception ex)
            {
                GD.PushError($"[C#] Error instantiating scene: {ex.Message}");
                return null;
            }
        }

        /// <summary>
        /// 示例：创建敌人（假设敌人是 GDScript）
        /// </summary>
        public Node? SpawnEnemy(string enemyType, Vector2 position)
        {
            string scenePath = $"res://scenes/enemies/{enemyType}.tscn";
            var enemy = InstantiateScene(scenePath);

            if (enemy != null && enemy is Node2D enemy2D)
            {
                enemy2D.Position = position;
                GetTree().CurrentScene.AddChild(enemy);
                GD.Print($"[C#] Spawned enemy '{enemyType}' at {position}");
            }

            return enemy;
        }

        /// <summary>
        /// 示例：创建特效（假设特效是 GDScript）
        /// </summary>
        public Node? SpawnEffect(string effectName, Vector2 position)
        {
            string scenePath = $"res://scenes/effects/{effectName}.tscn";
            var effect = InstantiateScene(scenePath);

            if (effect != null && effect is Node2D effect2D)
            {
                effect2D.Position = position;
                GetTree().CurrentScene.AddChild(effect);
                GD.Print($"[C#] Spawned effect '{effectName}' at {position}");
            }

            return effect;
        }

        #endregion

        #region Utility Methods

        /// <summary>
        /// 示例：检查 GDScript 节点是否有某个方法
        /// </summary>
        public bool HasMethod(string methodName)
        {
            if (_gameManager == null)
                return false;

            try
            {
                return _gameManager.HasMethod(methodName);
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// 示例：检查 GDScript 节点是否有某个信号
        /// </summary>
        public bool HasSignal(string signalName)
        {
            if (_gameManager == null)
                return false;

            try
            {
                // 在 Godot 4.x 中检查信号
                var signals = _gameManager.GetSignalList();
                foreach (Godot.Collections.Dictionary signal in signals)
                {
                    if (signal["name"].AsString() == signalName)
                    {
                        return true;
                    }
                }
                return false;
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// 示例：获取 GDScript 节点的所有方法
        /// </summary>
        public string[] GetMethodList()
        {
            if (_gameManager == null)
                return Array.Empty<string>();

            try
            {
                var methods = _gameManager.GetMethodList();
                var methodNames = new System.Collections.Generic.List<string>();

                foreach (Godot.Collections.Dictionary method in methods)
                {
                    methodNames.Add(method["name"].AsString());
                }

                return methodNames.ToArray();
            }
            catch
            {
                return Array.Empty<string>();
            }
        }

        /// <summary>
        /// 示例：延迟调用 GDScript 方法
        /// </summary>
        public void CallDeferredGdScript(string methodName, params Variant[] args)
        {
            if (_gameManager == null)
                return;

            _gameManager.CallDeferred(methodName, args);
        }

        #endregion
    }
}
