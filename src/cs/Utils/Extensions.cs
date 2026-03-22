using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.CompilerServices;
using Godot;

namespace DreamerHeroines.Utils
{
    /// <summary>
    /// Godot和C#扩展方法集合
    /// </summary>
    public static partial class Extensions
    {
        #region Node Extensions
        /// <summary>
        /// 安全获取节点，如果不存在返回null
        /// </summary>
        public static T? GetNodeOrNull<T>(this Node node, NodePath path)
            where T : Node
        {
            if (node.HasNode(path))
            {
                return node.GetNode<T>(path);
            }
            return null;
        }

        /// <summary>
        /// 获取或创建子节点
        /// </summary>
        public static T GetOrCreateChild<T>(this Node node, string name)
            where T : Node, new()
        {
            var existing = node.FindChild(name, false, false);
            if (existing is T typedNode)
            {
                return typedNode;
            }

            var newNode = new T { Name = name };
            node.AddChild(newNode);
            return newNode;
        }

        /// <summary>
        /// 递归查找所有指定类型的子节点
        /// </summary>
        public static IEnumerable<T> FindChildrenOfType<T>(this Node node, bool recursive = true)
            where T : Node
        {
            foreach (Node child in node.GetChildren())
            {
                if (child is T typedChild)
                {
                    yield return typedChild;
                }

                if (recursive)
                {
                    foreach (var grandChild in child.FindChildrenOfType<T>(true))
                    {
                        yield return grandChild;
                    }
                }
            }
        }

        /// <summary>
        /// 获取所有子节点的名称
        /// </summary>
        public static string[] GetChildNames(this Node node)
        {
            return node.GetChildren().Select(c => c.Name.ToString()).ToArray();
        }

        /// <summary>
        /// 延迟调用（使用Godot的Timer）
        /// </summary>
        public static void CallDeferred(this Node node, Action action, double delaySeconds)
        {
            var timer = new Timer
            {
                WaitTime = delaySeconds,
                OneShot = true,
                Autostart = true,
            };
            node.AddChild(timer);
            timer.Timeout += () =>
            {
                action?.Invoke();
                timer.QueueFree();
            };
        }

        /// <summary>
        /// 延迟调用一帧
        /// </summary>
        public static void CallNextFrame(this Node node, Action action)
        {
            node.CallDeferred(Node.MethodName.AddChild, new DeferredAction(action));
        }

        private partial class DeferredAction : Node
        {
            private readonly Action _action;

            public DeferredAction(Action action)
            {
                _action = action;
            }

            public override void _Ready()
            {
                _action?.Invoke();
                QueueFree();
            }
        }
        #endregion

        #region Node2D Extensions
        /// <summary>
        /// 平滑移动到目标位置
        /// </summary>
        public static void MoveTowards(this Node2D node, Vector2 target, float speed, double delta)
        {
            node.Position = node.Position.MoveToward(target, speed * (float)delta);
        }

        /// <summary>
        /// 平滑旋转到目标角度
        /// </summary>
        public static void RotateTowards(this Node2D node, float targetAngle, float speed, double delta)
        {
            float currentAngle = node.Rotation;
            float diff = Mathf.Wrap(targetAngle - currentAngle, -Mathf.Pi, Mathf.Pi);
            node.Rotation += Mathf.Sign(diff) * Mathf.Min(Mathf.Abs(diff), speed * (float)delta);
        }

        /// <summary>
        /// 面向目标位置
        /// </summary>
        public static void LookAt(this Node2D node, Vector2 target)
        {
            node.Rotation = (target - node.Position).Angle();
        }

        /// <summary>
        /// 获取朝向目标的向量
        /// </summary>
        public static Vector2 DirectionTo(this Node2D node, Vector2 target)
        {
            return (target - node.GlobalPosition).Normalized();
        }

        /// <summary>
        /// 获取与目标的距离
        /// </summary>
        public static float DistanceTo(this Node2D node, Vector2 target)
        {
            return node.GlobalPosition.DistanceTo(target);
        }

        /// <summary>
        /// 获取与目标的平方距离（性能更优）
        /// </summary>
        public static float DistanceSquaredTo(this Node2D node, Vector2 target)
        {
            return node.GlobalPosition.DistanceSquaredTo(target);
        }

        /// <summary>
        /// 在指定范围内查找最近的节点
        /// </summary>
        public static T? FindNearest<T>(this Node2D node, IEnumerable<T> candidates)
            where T : Node2D
        {
            T? nearest = null;
            float nearestDist = float.MaxValue;

            foreach (var candidate in candidates)
            {
                if (candidate == node)
                    continue;

                float dist = node.GlobalPosition.DistanceSquaredTo(candidate.GlobalPosition);
                if (dist < nearestDist)
                {
                    nearestDist = dist;
                    nearest = candidate;
                }
            }

            return nearest;
        }

        /// <summary>
        /// 设置全局位置（考虑父节点变换）
        /// </summary>
        public static void SetGlobalPosition(this Node2D node, Vector2 globalPosition)
        {
            if (node.GetParent() is Node2D parent)
            {
                node.Position = globalPosition - parent.GlobalPosition;
            }
            else
            {
                node.Position = globalPosition;
            }
        }

        /// <summary>
        /// 设置全局旋转（考虑父节点变换）
        /// </summary>
        public static void SetGlobalRotation(this Node2D node, float globalRotation)
        {
            if (node.GetParent() is Node2D parent)
            {
                node.Rotation = globalRotation - parent.GlobalRotation;
            }
            else
            {
                node.Rotation = globalRotation;
            }
        }
        #endregion

        #region Vector2 Extensions
        /// <summary>
        /// 向量旋转指定角度
        /// </summary>
        public static Vector2 RotatedBy(this Vector2 vector, float angle)
        {
            float cos = Mathf.Cos(angle);
            float sin = Mathf.Sin(angle);
            return new Vector2(vector.X * cos - vector.Y * sin, vector.X * sin + vector.Y * cos);
        }

        /// <summary>
        /// 获取垂直向量（顺时针90度）
        /// </summary>
        public static Vector2 Perpendicular(this Vector2 vector)
        {
            return new Vector2(-vector.Y, vector.X);
        }

        /// <summary>
        /// 获取向量的角度（度）
        /// </summary>
        public static float AngleDegrees(this Vector2 vector)
        {
            return Mathf.RadToDeg(vector.Angle());
        }

        /// <summary>
        /// 将向量限制在最大长度内
        /// </summary>
        public static Vector2 Clamped(this Vector2 vector, float maxLength)
        {
            if (vector.LengthSquared() > maxLength * maxLength)
            {
                return vector.Normalized() * maxLength;
            }
            return vector;
        }

        /// <summary>
        /// 向量线性插值
        /// </summary>
        public static Vector2 LerpTo(this Vector2 from, Vector2 to, float t)
        {
            return from.Lerp(to, t);
        }

        /// <summary>
        /// 带阻尼的向量移动
        /// </summary>
        public static Vector2 SmoothDamp(
            this Vector2 current,
            Vector2 target,
            ref Vector2 velocity,
            float smoothTime,
            float deltaTime,
            float maxSpeed = float.PositiveInfinity
        )
        {
            smoothTime = Math.Max(0.0001f, smoothTime);
            float omega = 2f / smoothTime;
            float x = omega * deltaTime;
            float exp = 1f / (1f + x + 0.48f * x * x + 0.235f * x * x * x);

            Vector2 change = current - target;
            Vector2 maxChange = Vector2.One * maxSpeed * smoothTime;
            change.X = Mathf.Clamp(change.X, -maxChange.X, maxChange.X);
            change.Y = Mathf.Clamp(change.Y, -maxChange.Y, maxChange.Y);

            Vector2 temp = (velocity + change * omega) * deltaTime;
            velocity = (velocity - temp * omega) * exp;
            Vector2 output = target + (change + temp) * exp;

            if ((target - current).Dot(output - target) > 0)
            {
                output = target;
                velocity = (output - target) / deltaTime;
            }

            return output;
        }

        /// <summary>
        /// 将向量舍入到网格
        /// </summary>
        public static Vector2 SnapToGrid(this Vector2 vector, float gridSize)
        {
            return new Vector2(
                Mathf.Round(vector.X / gridSize) * gridSize,
                Mathf.Round(vector.Y / gridSize) * gridSize
            );
        }

        /// <summary>
        /// 判断向量是否近似为零
        /// </summary>
        public static bool IsZeroApprox(this Vector2 vector, float tolerance = 0.0001f)
        {
            return Mathf.IsZeroApprox(vector.X) && Mathf.IsZeroApprox(vector.Y);
        }

        /// <summary>
        /// 获取向量的字符串表示（格式化）
        /// </summary>
        public static string ToString(this Vector2 vector, string format)
        {
            return $"({vector.X.ToString(format)}, {vector.Y.ToString(format)})";
        }
        #endregion

        #region String Extensions
        /// <summary>
        /// 截断字符串到指定长度
        /// </summary>
        public static string Truncate(this string value, int maxLength, string suffix = "...")
        {
            if (string.IsNullOrEmpty(value))
                return value;
            if (value.Length <= maxLength)
                return value;
            return value.Substring(0, maxLength - suffix.Length) + suffix;
        }

        /// <summary>
        /// 将字符串首字母大写
        /// </summary>
        public static string Capitalize(this string value)
        {
            if (string.IsNullOrEmpty(value))
                return value;
            return char.ToUpper(value[0]) + value.Substring(1);
        }

        /// <summary>
        /// 将驼峰命名转换为友好显示名称
        /// </summary>
        public static string ToDisplayName(this string value)
        {
            if (string.IsNullOrEmpty(value))
                return value;

            var result = new System.Text.StringBuilder(value.Length + 8);
            result.Append(char.ToUpper(value[0]));

            for (int i = 1; i < value.Length; i++)
            {
                if (char.IsUpper(value[i]))
                {
                    result.Append(' ');
                }
                result.Append(value[i]);
            }

            return result.ToString();
        }

        /// <summary>
        /// 解析为枚举值
        /// </summary>
        public static bool TryParseEnum<T>(this string value, out T result)
            where T : struct, Enum
        {
            return Enum.TryParse(value, true, out result);
        }

        /// <summary>
        /// 获取字符串的MD5哈希
        /// </summary>
        public static string ToMD5(this string input)
        {
            using var md5 = System.Security.Cryptography.MD5.Create();
            byte[] inputBytes = System.Text.Encoding.UTF8.GetBytes(input);
            byte[] hashBytes = md5.ComputeHash(inputBytes);
            return Convert.ToHexString(hashBytes);
        }
        #endregion

        #region Collection Extensions
        /// <summary>
        /// 随机打乱列表
        /// </summary>
        public static void Shuffle<T>(this IList<T> list)
        {
            Random rng = new Random();
            int n = list.Count;
            while (n > 1)
            {
                n--;
                int k = rng.Next(n + 1);
                (list[n], list[k]) = (list[k], list[n]);
            }
        }

        /// <summary>
        /// 获取随机元素
        /// </summary>
        public static T? RandomElement<T>(this IList<T> list)
        {
            if (list.Count == 0)
                return default;
            return list[new Random().Next(list.Count)];
        }

        /// <summary>
        /// 获取随机元素（带权重）
        /// </summary>
        public static T? RandomElementWeighted<T>(this IList<T> list, Func<T, float> weightSelector)
        {
            if (list.Count == 0)
                return default;

            float totalWeight = list.Sum(weightSelector);
            float random = (float)new Random().NextDouble() * totalWeight;

            float current = 0;
            foreach (var item in list)
            {
                current += weightSelector(item);
                if (random <= current)
                {
                    return item;
                }
            }

            return list[^1];
        }

        /// <summary>
        /// 将列表分批
        /// </summary>
        public static IEnumerable<IEnumerable<T>> Batch<T>(this IEnumerable<T> source, int batchSize)
        {
            var batch = new List<T>(batchSize);
            foreach (var item in source)
            {
                batch.Add(item);
                if (batch.Count >= batchSize)
                {
                    yield return batch;
                    batch = new List<T>(batchSize);
                }
            }

            if (batch.Count > 0)
            {
                yield return batch;
            }
        }

        /// <summary>
        /// 安全获取字典值
        /// </summary>
        public static TValue? GetValueOrDefault<TKey, TValue>(
            this Dictionary<TKey, TValue> dict,
            TKey key,
            TValue? defaultValue = default
        )
            where TKey : notnull
        {
            if (dict.TryGetValue(key, out var value))
            {
                return value;
            }
            return defaultValue;
        }

        /// <summary>
        /// 添加或更新字典值
        /// </summary>
        public static void AddOrUpdate<TKey, TValue>(this Dictionary<TKey, TValue> dict, TKey key, TValue value)
            where TKey : notnull
        {
            dict[key] = value;
        }
        #endregion

        #region Godot Array Extensions
        /// <summary>
        /// 将Godot数组转换为C#列表
        /// </summary>
        public static List<T> ToList<T>(this Godot.Collections.Array array)
        {
            var list = new List<T>(array.Count);
            foreach (var item in array)
            {
                if (item is T typedItem)
                {
                    list.Add(typedItem);
                }
            }
            return list;
        }

        /// <summary>
        /// 将C#列表转换为Godot数组
        /// </summary>
        public static Godot.Collections.Array ToGodotArray<T>(this IEnumerable<T> enumerable)
        {
            var array = new Godot.Collections.Array();
            foreach (var item in enumerable)
            {
                array.Add(Variant.From(item));
            }
            return array;
        }

        /// <summary>
        /// 将C#字典转换为Godot字典
        /// </summary>
        public static Godot.Collections.Dictionary ToGodotDictionary<TKey, TValue>(this Dictionary<TKey, TValue> dict)
            where TKey : notnull
        {
            var godotDict = new Godot.Collections.Dictionary();
            foreach (var kvp in dict)
            {
                godotDict[Variant.From(kvp.Key)] = Variant.From(kvp.Value);
            }
            return godotDict;
        }
        #endregion

        #region Color Extensions
        /// <summary>
        /// 调整颜色亮度
        /// </summary>
        public static Color WithBrightness(this Color color, float brightness)
        {
            return new Color(color.R * brightness, color.G * brightness, color.B * brightness, color.A);
        }

        /// <summary>
        /// 调整颜色透明度
        /// </summary>
        public static Color WithAlpha(this Color color, float alpha)
        {
            return new Color(color.R, color.G, color.B, alpha);
        }

        /// <summary>
        /// 混合两种颜色
        /// </summary>
        public static Color Blend(this Color color1, Color color2, float t)
        {
            return color1.Lerp(color2, t);
        }
        #endregion

        #region Rect2 Extensions
        /// <summary>
        /// 获取矩形中心点
        /// </summary>
        public static Vector2 Center(this Rect2 rect)
        {
            return rect.Position + rect.Size / 2;
        }

        /// <summary>
        /// 扩展矩形
        /// </summary>
        public static Rect2 Expand(this Rect2 rect, float amount)
        {
            return new Rect2(
                rect.Position - new Vector2(amount, amount),
                rect.Size + new Vector2(amount * 2, amount * 2)
            );
        }

        /// <summary>
        /// 收缩矩形
        /// </summary>
        public static Rect2 Shrink(this Rect2 rect, float amount)
        {
            return rect.Expand(-amount);
        }

        /// <summary>
        /// 检查点是否在矩形内（包含边界）
        /// </summary>
        public static bool ContainsInclusive(this Rect2 rect, Vector2 point)
        {
            return point.X >= rect.Position.X
                && point.X <= rect.End.X
                && point.Y >= rect.Position.Y
                && point.Y <= rect.End.Y;
        }
        #endregion

        #region Timer Extensions
        /// <summary>
        /// 创建一次性计时器
        /// </summary>
        public static Timer CreateOneShot(this SceneTree tree, double waitTime, Action callback)
        {
            var timer = new Timer
            {
                WaitTime = waitTime,
                OneShot = true,
                Autostart = true,
            };

            timer.Timeout += () =>
            {
                callback?.Invoke();
                timer.QueueFree();
            };

            tree.Root.AddChild(timer);
            return timer;
        }

        /// <summary>
        /// 延迟执行
        /// </summary>
        public static void Delay(this SceneTree tree, double seconds, Action callback)
        {
            tree.CreateOneShot(seconds, callback);
        }
        #endregion

        #region Math Extensions
        /// <summary>
        /// 将值映射到另一个范围
        /// </summary>
        public static float Remap(this float value, float fromMin, float fromMax, float toMin, float toMax)
        {
            return Mathf.Lerp(toMin, toMax, Mathf.InverseLerp(fromMin, fromMax, value));
        }

        /// <summary>
        /// 将值映射到另一个范围
        /// </summary>
        public static double Remap(this double value, double fromMin, double fromMax, double toMin, double toMax)
        {
            double t = (value - fromMin) / (fromMax - fromMin);
            return toMin + t * (toMax - toMin);
        }

        /// <summary>
        /// 将角度标准化到 -180 到 180 度
        /// </summary>
        public static float NormalizeAngle180(this float angle)
        {
            angle = angle % 360f;
            if (angle > 180f)
                angle -= 360f;
            if (angle < -180f)
                angle += 360f;
            return angle;
        }

        /// <summary>
        /// 将角度标准化到 0 到 360 度
        /// </summary>
        public static float NormalizeAngle360(this float angle)
        {
            angle = angle % 360f;
            if (angle < 0f)
                angle += 360f;
            return angle;
        }
        #endregion
    }
}
