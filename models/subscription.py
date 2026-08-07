from sqlalchemy import Column, Integer, String, DateTime, Date
from database import Base
from datetime import datetime, date
class Subscription(Base):
    __tablename__ = 'subscriptions'
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, index=True)
    plan = Column(String(20), default="free")
    messages_used = Column(Integer, default=0)
    last_reset = Column(Date, default=date.today)
    expires_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)