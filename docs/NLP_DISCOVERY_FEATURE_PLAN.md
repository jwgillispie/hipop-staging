# NLP Discovery Feature Plan for HiPOP

## Vision
Transform HiPOP's discovery experience by allowing users to search using natural language instead of traditional filters and forms.

## Core Concept
Users can type or speak naturally to find markets and vendors:
- "Find me vintage markets this weekend with free parking"
- "Show vendors selling handmade jewelry under $50"
- "Markets near Piedmont Park accepting food vendors"

## Target User Queries

### Vendors Searching for Markets
- "Markets near me this weekend that accept jewelry vendors"
- "Find farmers markets in Atlanta that don't require permits"
- "Show me holiday markets in December with indoor spaces"
- "Markets tomorrow with available spots under $50"
- "Any markets looking for vegan food vendors?"
- "Christmas craft fairs within 20 miles"
- "Pop-ups that allow CBD products"

### Shoppers Searching for Markets
- "What's happening tonight near me?"
- "Christmas markets with free parking"
- "Kid-friendly markets this Saturday morning"
- "Find me that market with the good tamales"
- "Vintage markets in Little Five Points"
- "Dog-friendly outdoor markets"
- "Markets with live music this weekend"

### Shoppers Searching for Vendors
- "That soap lady from last week"
- "Vendors selling succulents"
- "Find gluten-free bakeries at tomorrow's market"
- "Black-owned businesses at Piedmont market"
- "Cheapest jewelry vendors near me"
- "Organic produce vendors open now"
- "Vendors that accept Apple Pay"

### Markets Searching for Vendors
- "Food trucks available this Sunday"
- "Find me vendors who haven't missed a market in 6 months"
- "New vendors with 5-star ratings"
- "Vendors that match my bohemian market vibe"
- "Show me produce vendors who accept EBT"
- "Reliable vendors with their own insurance"
- "Top-selling vendors from last quarter"

## Query Parse Pattern

Every natural language query contains these elements:

### 1. WHO (Entity Type)
- Markets
- Vendors
- Events
- Products

### 2. WHEN (Temporal)
- Specific dates: "December 15th", "tomorrow"
- Recurring: "every Sunday", "weekends"
- Ranges: "this week", "next month"
- Times: "morning", "after 5pm"

### 3. WHERE (Location)
- Relative: "near me", "within 10 miles"
- Specific: "Piedmont Park", "Downtown Atlanta"
- Areas: "East Atlanta", "Little Five Points"
- Attributes: "indoor", "covered", "with parking"

### 4. WHAT (Attributes)
- Product types: "jewelry", "vintage", "organic"
- Price ranges: "under $50", "free admission"
- Amenities: "parking", "bathrooms", "ATM"
- Requirements: "no permit", "accepts EBT"

### 5. VIBE (Soft Attributes)
- Atmosphere: "family-friendly", "hipster", "upscale"
- Quality: "highly-rated", "popular", "new"
- Style: "bohemian", "artisanal", "sustainable"

## Technical Implementation

### Phase 1: MVP with Gemini Flash
```javascript
// Example prompt structure
const parseQuery = async (userInput) => {
  const prompt = `
    Extract search parameters from this query: "${userInput}"
    
    Return as JSON:
    {
      entityType: "market|vendor|event",
      when: {
        date: "ISO date or null",
        dayOfWeek: "string or null",
        timeRange: "morning|afternoon|evening|null"
      },
      where: {
        location: "string or null",
        radius: "number in miles or null",
        locationType: "indoor|outdoor|covered|null"
      },
      what: {
        category: "string or null",
        priceRange: {min: number, max: number},
        features: ["array of features"]
      },
      vibe: ["array of soft attributes"]
    }
  `;
  
  return await gemini.generateContent(prompt);
};
```

### Phase 2: Enhanced Accuracy
- Add few-shot learning examples
- Implement confidence scoring
- Add fallback to traditional search if confidence < 80%
- Cache common queries

### Phase 3: Production Scale
- Consider upgrading to GPT-4 or Claude for complex queries
- Implement query suggestion/autocomplete
- Add voice input support
- Multi-language support

## Implementation Priority

### Quick Wins (Week 1)
1. Basic market discovery for vendors
2. Simple vendor search for shoppers
3. Date/time parsing (this weekend, tomorrow, etc.)

### Core Features (Week 2-3)
1. Location-based queries
2. Multi-attribute filtering
3. Price range understanding
4. Category matching

### Advanced Features (Month 2)
1. Vibe/style matching
2. Historical references ("that vendor from last week")
3. Complex boolean logic ("markets with either jewelry OR vintage clothing")
4. Predictive suggestions

## Success Metrics
- Query success rate (target: 85% accurate on first try)
- Time to find desired result (target: 50% faster than traditional search)
- User adoption rate (target: 40% of searches use NLP within 3 months)
- Query complexity evolution (users trying more complex queries over time)

## Cost Analysis

### Gemini Flash (Current Choice)
- Cost: FREE with Firebase
- Accuracy estimate: 85-90% with good prompting
- Response time: ~1 second
- Best for: MVP and initial rollout

### OpenAI GPT-4 (Future Option)
- Cost: ~$20-50/month for expected volume
- Accuracy estimate: 95-99%
- Response time: 2-3 seconds
- Best for: When revenue justifies cost

### Hybrid Approach
- Use Gemini for simple queries (80% of volume)
- Route complex queries to GPT-4 (20% of volume)
- Total cost: ~$10-15/month

## Example User Flow

1. User taps search bar
2. Sees prompt: "Try asking: 'Find vintage markets this weekend'"
3. Types: "organic farmers markets near me tomorrow morning"
4. System parses:
   - Entity: market
   - Category: farmers market, organic
   - When: tomorrow, morning
   - Where: user location
5. Returns filtered Firestore results
6. Falls back to traditional search if parse confidence < 80%

## Training Data Examples

```json
[
  {
    "input": "Find me vintage markets this weekend with free parking",
    "output": {
      "entityType": "market",
      "when": {"dayOfWeek": ["Saturday", "Sunday"]},
      "what": {"category": "vintage", "features": ["free parking"]}
    }
  },
  {
    "input": "Jewelry vendors under 50 dollars at Piedmont Park",
    "output": {
      "entityType": "vendor",
      "what": {"category": "jewelry", "priceRange": {"max": 50}},
      "where": {"location": "Piedmont Park"}
    }
  }
]
```

## Competitive Advantage
- No other market platform offers NLP search
- Reduces friction for non-technical users
- Enables voice commerce future
- Creates switching cost (users get used to natural search)
- Gathering training data creates moat over time

## Next Steps
1. Create proof of concept with Gemini Flash
2. Test with 10-20 real user queries
3. Measure accuracy and refine prompts
4. Build fallback to traditional search
5. Ship as beta feature to subset of users
6. Iterate based on usage data
7. Scale up model if needed based on ROI

## Future Possibilities
- Voice input: "Hey HiPOP, what's happening tonight?"
- Proactive suggestions: "Markets you might like this weekend"
- Conversational commerce: "Book me a spot at that market"
- Multi-turn conversations: "Show me cheaper options" 
- Predictive inventory: "Will there be succulents at tomorrow's market?"