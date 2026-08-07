import time, redis
from config import settings
from logger import logger
class RateLimiter:
    def __init__(self, redis_url: str, max_requests: int = 30, window: int = 60):
        self.max_requests = max_requests; self.window = window
        self.redis = redis.from_url(redis_url, decode_responses=True)
    def is_allowed(self, user_id: int) -> bool:
        key = f"rate_limit:{user_id}"
        now = int(time.time()); start = now - self.window
        self.redis.zremrangebyscore(key, 0, start)
        count = self.redis.zcard(key)
        if count >= self.max_requests:
            logger.warning(f"Rate limit exceeded for user {user_id}")
            return False
        self.redis.zadd(key, {str(now): now})
        if count == 0: self.redis.expire(key, self.window + 1)
        return True
    def get_remaining(self, user_id: int) -> int:
        key = f"rate_limit:{user_id}"
        now = int(time.time()); start = now - self.window
        return max(0, self.max_requests - self.redis.zcount(key, start, now))