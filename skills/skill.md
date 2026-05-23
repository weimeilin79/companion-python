---
name: Agent Development Kit (ADK) Python Developer
id: adk_python_developer
description: Skill for building, orchestrating, and testing AI agents using the Google Agent Development Kit (ADK) in Python.
tags: [python, adk, agent, orchestration, llm, google-ai]
---

# Agent Development Kit (ADK) Python Developer Skill

This skill provides comprehensive instructions, patterns, and code reference for building, orchestrating, and testing single-agent and multi-agent systems using the Google Agent Development Kit (ADK) in Python.

---

## 🚀 Installation & Setup

Install the stable release of ADK:
```bash
pip install google-adk
```

Or install the development version directly from GitHub:
```bash
pip install git+https://github.com/google/adk-python.git@main
```

---

## 🤖 1. Basic Agent Definition (`LlmAgent`)

The `LlmAgent` class (often imported as `Agent`) utilizes a Large Language Model (LLM) for reasoning, decision-making, and responding.

### Core Configuration Parameters:
- `name` (str): Unique identifier for the agent (used in multi-agent routing).
- `model` (str): Gemini model identifier (e.g. `"gemini-2.5-flash"`).
- `instruction` (str): Persona, constraints, formatting rules, and tool guidelines.
- `description` (str): Purpose and capabilities (used by coordinator agents for routing).
- `tools` (list): Prebuilt or custom tools the agent can invoke.
- `output_key` (str, optional): Key where the final response is written in the session state.

### Code Pattern:
```python
from google.adk.agents import LlmAgent
from google.adk.tools import google_search

search_assistant = LlmAgent(
    name="search_assistant",
    model="gemini-2.5-flash",
    description="An assistant that can search the web to answer recent questions.",
    instruction="""
    You are a helpful search assistant.
    Always use the `google_search` tool if you need information about recent events.
    Be concise and answer in no more than 3 sentences.
    """,
    tools=[google_search],
    output_key="search_result"
)
```

---

## 🔧 2. Custom Tools Definition

Tools can be defined by writing standard Python functions with clear docstrings and type hints. The ADK uses the function signatures and docstrings to generate schemas for the model.

### Code Pattern:
```python
def calculate_compound_interest(principal: float, rate: float, years: int) -> float:
    """Calculates the compound interest for a principal amount.

    Args:
        principal: The starting capital amount.
        rate: The annual interest rate (as a decimal, e.g. 0.05 for 5%).
        years: The number of years to invest.

    Returns:
        The total accumulated amount including interest.
    """
    return principal * ((1 + rate) ** years)

# Add the tool to an LlmAgent
finance_agent = LlmAgent(
    name="FinanceAgent",
    model="gemini-2.5-flash",
    instruction="Answer finance questions. Use compound interest tool for calculations.",
    tools=[calculate_compound_interest]
)
```

---

## 🔀 3. Workflow Agents

Workflow Agents orchestrate multiple child agents in deterministic patterns without needing an LLM for control flow.

### A. Sequential Agent
Executes sub-agents one after another. Session state is passed automatically between steps.
```python
from google.adk.agents import SequentialAgent

processing_flow = SequentialAgent(
    name="ProcessingFlow",
    sub_agents=[grammar_check_agent, tone_check_agent]
)
```

### B. Loop Agent
Repeatedly runs a set of sub-agents until a maximum number of iterations is reached or a loop condition is satisfied.
```python
from google.adk.agents import LoopAgent

refinement_loop = LoopAgent(
    name="RefinementLoop",
    sub_agents=[critic_agent, reviser_agent],
    max_iterations=3
)
```

### C. Parallel Agent
Runs sub-agents concurrently.
```python
from google.adk.agents import ParallelAgent

multitask_flow = ParallelAgent(
    name="MultiTaskFlow",
    sub_agents=[sentiment_agent, summarization_agent]
)
```

---

## 🛠️ 4. Custom Agents (`BaseAgent` Subclass)

For conditional branching, complex state management, or external API integrations, create a Custom Agent by subclassing `BaseAgent`.

### Key Implementation Guidelines:
1. **Subclass `BaseAgent`**: Inherit directly from `BaseAgent`.
2. **Pydantic Fields**: Because ADK agents use Pydantic, define type hints for all child agents as class-level field declarations. Set `model_config = {"arbitrary_types_allowed": True}`.
3. **Framework Registration**: Pass all sub-agents to `super().__init__(..., sub_agents=[...])` so the engine registered them.
4. **Implement `_run_async_impl`**: Override the async execution method.

### Code Pattern:
```python
import logging
from typing import AsyncGenerator
from typing_extensions import override
from google.adk.agents import BaseAgent, LlmAgent, LoopAgent, SequentialAgent
from google.adk.agents.invocation_context import InvocationContext
from google.adk.events import Event

logger = logging.getLogger(__name__)

class StoryFlowAgent(BaseAgent):
    """Custom agent orchestrating story generation and tone-based regeneration."""
    
    # 1. Field declarations for Pydantic
    story_generator: LlmAgent
    critic: LlmAgent
    reviser: LlmAgent
    grammar_check: LlmAgent
    tone_check: LlmAgent
    
    loop_agent: LoopAgent
    sequential_agent: SequentialAgent
    
    model_config = {"arbitrary_types_allowed": True}

    def __init__(
        self,
        name: str,
        story_generator: LlmAgent,
        critic: LlmAgent,
        reviser: LlmAgent,
        grammar_check: LlmAgent,
        tone_check: LlmAgent
    ):
        # Instantiate workflow helpers
        loop_agent = LoopAgent(
            name="CriticReviserLoop", sub_agents=[critic, reviser], max_iterations=2
        )
        sequential_agent = SequentialAgent(
            name="PostProcessing", sub_agents=[grammar_check, tone_check]
        )
        
        # Sub-agents list for the framework
        sub_agents_list = [story_generator, loop_agent, sequential_agent]
        
        super().__init__(
            name=name,
            story_generator=story_generator,
            critic=critic,
            reviser=reviser,
            grammar_check=grammar_check,
            tone_check=tone_check,
            loop_agent=loop_agent,
            sequential_agent=sequential_agent,
            sub_agents=sub_agents_list
        )

    @override
    async def _run_async_impl(self, ctx: InvocationContext) -> AsyncGenerator[Event, None]:
        logger.info(f"[{self.name}] Starting story generation workflow.")
        
        # 1. Run Story Generator
        async for event in self.story_generator.run_async(ctx):
            yield event
            
        # Check if story exists in state
        if "current_story" not in ctx.session.state or not ctx.session.state["current_story"]:
            logger.error("Failed to generate initial story. Aborting.")
            return

        # 2. Run Critic/Reviser Loop
        async for event in self.loop_agent.run_async(ctx):
            yield event

        # 3. Run Post-Processing checks (Grammar + Tone)
        async for event in self.sequential_agent.run_async(ctx):
            yield event

        # 4. Conditional Branching based on Session State
        tone_check_result = ctx.session.state.get("tone_check_result")
        if tone_check_result == "negative":
            logger.info("Tone is negative. Regenerating story...")
            async for event in self.story_generator.run_async(ctx):
                yield event
```

---

## 🏃‍♂️ 5. Execution & Session Management

To run an agent, configure an `InMemorySessionService` and use the `Runner`.

### Code Pattern:
```python
import asyncio
from google.adk.sessions import InMemorySessionService
from google.adk.runners import Runner
from google.genai import types

async def main():
    # 1. Initialize session and runner
    session_service = InMemorySessionService()
    session = await session_service.create_session(
        app_name="story_app", 
        user_id="123", 
        session_id="session_001", 
        state={"topic": "a brave kitten"}
    )
    
    runner = Runner(
        agent=story_flow_agent,
        app_name="story_app",
        session_service=session_service
    )
    
    # 2. Package user prompt
    content = types.Content(
        role="user", 
        parts=[types.Part(text="Generate a story")]
    )
    
    # 3. Run agent asynchronously and capture event stream
    events = runner.run_async(
        user_id="123", 
        session_id="session_001", 
        new_message=content
    )
    
    async for event in events:
        if event.is_final_response() and event.content and event.content.parts:
            print("Response:", event.content.parts[0].text)

if __name__ == "__main__":
    asyncio.run(main())
```