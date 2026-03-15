using Godot;
using System;

namespace StrikeForceLike.Core
{
    /// <summary>
    /// 游戏数学工具类，提供常用的数学函数和缓动函数
    /// </summary>
    public static class MathUtils
    {
        #region Constants
        public const float PI = MathF.PI;
        public const float TAU = MathF.PI * 2f;
        public const float DEG2RAD = MathF.PI / 180f;
        public const float RAD2DEG = 180f / MathF.PI;
        public const float EPSILON = 1e-6f;
        #endregion

        #region Clamp Functions
        /// <summary>
        /// 将值限制在指定范围内
        /// </summary>
        public static float Clamp(float value, float min, float max)
        {
            return value < min ? min : (value > max ? max : value);
        }

        /// <summary>
        /// 将值限制在0-1范围内
        /// </summary>
        public static float Clamp01(float value)
        {
            return value < 0f ? 0f : (value > 1f ? 1f : value);
        }

        /// <summary>
        /// 将整数值限制在指定范围内
        /// </summary>
        public static int Clamp(int value, int min, int max)
        {
            return value < min ? min : (value > max ? max : value);
        }
        #endregion

        #region Easing Functions
        /// <summary>
        /// 线性插值
        /// </summary>
        public static float Lerp(float a, float b, float t)
        {
            return a + (b - a) * Clamp01(t);
        }

        /// <summary>
        /// 向量线性插值
        /// </summary>
        public static Vector2 Lerp(Vector2 a, Vector2 b, float t)
        {
            return a.Lerp(b, Clamp01(t));
        }

        /// <summary>
        /// 平滑插值（适用于每帧调用）
        /// </summary>
        public static float SmoothDamp(float current, float target, ref float velocity, float smoothTime, float deltaTime, float maxSpeed = float.PositiveInfinity)
        {
            smoothTime = Math.Max(0.0001f, smoothTime);
            float omega = 2f / smoothTime;
            float x = omega * deltaTime;
            float exp = 1f / (1f + x + 0.48f * x * x + 0.235f * x * x * x);
            float change = current - target;
            float maxChange = maxSpeed * smoothTime;
            change = Clamp(change, -maxChange, maxChange);
            float temp = (velocity + omega * change) * deltaTime;
            velocity = (velocity - omega * temp) * exp;
            float output = target + (change + temp) * exp;
            if (target - current > 0f == output > target)
            {
                output = target;
                velocity = (output - target) / deltaTime;
            }
            return output;
        }

        /// <summary>
        /// 平滑步进插值
        /// </summary>
        public static float SmoothStep(float from, float to, float t)
        {
            t = Clamp01(t);
            t = -2f * t * t * t + 3f * t * t;
            return to * t + from * (1f - t);
        }

        /// <summary>
        /// 缓动进入（二次）
        /// </summary>
        public static float EaseInQuad(float t)
        {
            return t * t;
        }

        /// <summary>
        /// 缓动退出（二次）
        /// </summary>
        public static float EaseOutQuad(float t)
        {
            return 1f - (1f - t) * (1f - t);
        }

        /// <summary>
        /// 缓动进入退出（二次）
        /// </summary>
        public static float EaseInOutQuad(float t)
        {
            return t < 0.5f ? 2f * t * t : 1f - MathF.Pow(-2f * t + 2f, 2f) / 2f;
        }

        /// <summary>
        /// 缓动进入（三次）
        /// </summary>
        public static float EaseInCubic(float t)
        {
            return t * t * t;
        }

        /// <summary>
        /// 缓动退出（三次）
        /// </summary>
        public static float EaseOutCubic(float t)
        {
            return 1f - MathF.Pow(1f - t, 3f);
        }

        /// <summary>
        /// 弹性缓动
        /// </summary>
        public static float EaseOutElastic(float t)
        {
            const float c4 = (2f * PI) / 3f;
            return t == 0f ? 0f : t == 1f ? 1f : MathF.Pow(2f, -10f * t) * MathF.Sin((t * 10f - 0.75f) * c4) + 1f;
        }

        /// <summary>
        /// 弹跳缓动
        /// </summary>
        public static float EaseOutBounce(float t)
        {
            const float n1 = 7.5625f;
            const float d1 = 2.75f;

            if (t < 1f / d1)
            {
                return n1 * t * t;
            }
            else if (t < 2f / d1)
            {
                return n1 * (t -= 1.5f / d1) * t + 0.75f;
            }
            else if (t < 2.5f / d1)
            {
                return n1 * (t -= 2.25f / d1) * t + 0.9375f;
            }
            else
            {
                return n1 * (t -= 2.625f / d1) * t + 0.984375f;
            }
        }
        #endregion

        #region Random Functions
        private static readonly Random _random = new Random();

        /// <summary>
        /// 获取0-1之间的随机浮点数
        /// </summary>
        public static float RandomFloat()
        {
            return (float)_random.NextDouble();
        }

        /// <summary>
        /// 获取指定范围内的随机浮点数
        /// </summary>
        public static float RandomRange(float min, float max)
        {
            return min + (float)_random.NextDouble() * (max - min);
        }

        /// <summary>
        /// 获取指定范围内的随机整数
        /// </summary>
        public static int RandomRange(int min, int max)
        {
            return _random.Next(min, max);
        }

        /// <summary>
        /// 获取随机方向向量
        /// </summary>
        public static Vector2 RandomDirection()
        {
            float angle = RandomRange(0f, TAU);
            return new Vector2(MathF.Cos(angle), MathF.Sin(angle));
        }

        /// <summary>
        /// 获取圆形内的随机点
        /// </summary>
        public static Vector2 RandomPointInCircle(float radius)
        {
            float r = radius * MathF.Sqrt(RandomFloat());
            float theta = RandomRange(0f, TAU);
            return new Vector2(r * MathF.Cos(theta), r * MathF.Sin(theta));
        }

        /// <summary>
        /// 获取矩形内的随机点
        /// </summary>
        public static Vector2 RandomPointInRect(Rect2 rect)
        {
            return new Vector2(
                RandomRange(rect.Position.X, rect.End.X),
                RandomRange(rect.Position.Y, rect.End.Y)
            );
        }

        /// <summary>
        /// 根据权重随机选择索引
        /// </summary>
        public static int WeightedRandom(float[] weights)
        {
            float total = 0f;
            foreach (float w in weights)
                total += w;

            float random = RandomFloat() * total;
            float current = 0f;

            for (int i = 0; i < weights.Length; i++)
            {
                current += weights[i];
                if (random <= current)
                    return i;
            }

            return weights.Length - 1;
        }
        #endregion

        #region Angle Functions
        /// <summary>
        /// 将角度标准化到0-360度
        /// </summary>
        public static float NormalizeAngle(float angle)
        {
            while (angle < 0f) angle += 360f;
            while (angle >= 360f) angle -= 360f;
            return angle;
        }

        /// <summary>
        /// 获取两个角度之间的最短差值
        /// </summary>
        public static float DeltaAngle(float current, float target)
        {
            float delta = NormalizeAngle(target - current);
            if (delta > 180f) delta -= 360f;
            return delta;
        }

        /// <summary>
        /// 向目标角度平滑旋转
        /// </summary>
        public static float RotateTowards(float current, float target, float maxDelta)
        {
            float delta = DeltaAngle(current, target);
            if (-maxDelta < delta && delta < maxDelta)
                return target;
            return current + Math.Sign(delta) * maxDelta;
        }

        /// <summary>
        /// 向量转角度（度）
        /// </summary>
        public static float VectorToAngle(Vector2 vector)
        {
            return Mathf.RadToDeg(MathF.Atan2(vector.Y, vector.X));
        }

        /// <summary>
        /// 角度转向量
        /// </summary>
        public static Vector2 AngleToVector(float angleDegrees)
        {
            float rad = Mathf.DegToRad(angleDegrees);
            return new Vector2(MathF.Cos(rad), MathF.Sin(rad));
        }
        #endregion

        #region Vector Functions
        /// <summary>
        /// 计算两点之间的距离（平方，避免开方运算）
        /// </summary>
        public static float DistanceSquared(Vector2 a, Vector2 b)
        {
            float dx = b.X - a.X;
            float dy = b.Y - a.Y;
            return dx * dx + dy * dy;
        }

        /// <summary>
        /// 判断点是否在矩形内
        /// </summary>
        public static bool PointInRect(Vector2 point, Rect2 rect)
        {
            return point.X >= rect.Position.X && point.X <= rect.End.X &&
                   point.Y >= rect.Position.Y && point.Y <= rect.End.Y;
        }

        /// <summary>
        /// 判断点是否在圆内
        /// </summary>
        public static bool PointInCircle(Vector2 point, Vector2 center, float radius)
        {
            return DistanceSquared(point, center) <= radius * radius;
        }

        /// <summary>
        /// 将向量限制在最大长度内
        /// </summary>
        public static Vector2 ClampMagnitude(Vector2 vector, float maxLength)
        {
            float sqrMagnitude = vector.LengthSquared();
            if (sqrMagnitude > maxLength * maxLength)
            {
                float scale = maxLength / MathF.Sqrt(sqrMagnitude);
                return vector * scale;
            }
            return vector;
        }
        #endregion

        #region Interpolation
        /// <summary>
        /// 球面线性插值（用于旋转）
        /// </summary>
        public static float Slerp(float a, float b, float t)
        {
            float delta = DeltaAngle(a, b);
            return a + delta * Clamp01(t);
        }

        /// <summary>
        /// 阻尼插值（适用于平滑跟随）
        /// </summary>
        public static float Damp(float a, float b, float lambda, float dt)
        {
            return Lerp(a, b, 1f - MathF.Exp(-lambda * dt));
        }

        /// <summary>
        /// 向量阻尼插值
        /// </summary>
        public static Vector2 Damp(Vector2 a, Vector2 b, float lambda, float dt)
        {
            return a.Lerp(b, 1f - MathF.Exp(-lambda * dt));
        }
        #endregion

        #region Utility
        /// <summary>
        /// 判断两个浮点数是否近似相等
        /// </summary>
        public static bool Approximately(float a, float b, float tolerance = EPSILON)
        {
            return MathF.Abs(b - a) < tolerance;
        }

        /// <summary>
        /// 将值映射到另一个范围
        /// </summary>
        public static float Remap(float value, float fromMin, float fromMax, float toMin, float toMax)
        {
            float t = (value - fromMin) / (fromMax - fromMin);
            return Lerp(toMin, toMax, t);
        }

        /// <summary>
        /// 重复值（类似取模，但支持浮点数）
        /// </summary>
        public static float Repeat(float value, float length)
        {
            return value - MathF.Floor(value / length) * length;
        }

        /// <summary>
        /// 乒乓值（在0-length之间来回）
        /// </summary>
        public static float PingPong(float value, float length)
        {
            value = Repeat(value, length * 2f);
            return length - MathF.Abs(value - length);
        }
        #endregion
    }
}
