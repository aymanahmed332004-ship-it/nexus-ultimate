import pytest
from agents.manager import AgentManager

@pytest.mark.asyncio
async def test_get_agent():
    agent = await AgentManager.get_agent("اكتب كود Python")
    assert agent.name == "coding"
    agent = await AgentManager.get_agent("ابحث عن أخبار مصر")
    assert agent.name == "search"
    agent = await AgentManager.get_agent("صمم واجهة احترافية")
    assert agent.name == "design"