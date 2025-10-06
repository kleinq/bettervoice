#!/usr/bin/env swift

//
//  generate_training_data.swift
//  Training data generator for text classification
//
//  Generates CSV with labeled text examples for 6 categories
//

import Foundation

// MARK: - Training Examples

let emailExamples = [
    "Dear hiring manager, I am writing to express my interest in the software engineering position at your company.",
    "Dear Sir or Madam, I would like to inquire about the status of my application submitted last week.",
    "Dear colleagues, Please find attached the quarterly report for your review.",
    "Dear team, I wanted to follow up on our discussion from yesterday's meeting regarding the project timeline.",
    "Dear Dr. Smith, Thank you for taking the time to speak with me about the research opportunity.",
    "Dear Customer Service, I am writing to request a refund for order number 12345.",
    "Dear valued customer, We are pleased to inform you about our new product launch.",
    "Dear Board Members, I am writing to provide an update on the company's financial performance.",
    "Dear Professor Johnson, I hope this email finds you well. I wanted to discuss my thesis proposal.",
    "Dear Support Team, I am experiencing technical difficulties with your software application.",
    "Good morning, I am reaching out regarding the upcoming conference scheduled for next month.",
    "Hello, I would like to schedule a meeting to discuss the partnership opportunity.",
    "Greetings, I am writing on behalf of our organization to request your participation.",
    "Dear friends and family, We are excited to announce our upcoming wedding celebration.",
    "Dear Editor, I am submitting my manuscript for consideration in your journal.",
    "To whom it may concern, I am writing to provide a reference for my former colleague.",
    "Dear recruiter, I came across your job posting and believe I would be a great fit.",
    "Dear Alumni, We cordially invite you to our annual reunion event.",
    "Dear subscribers, We wanted to update you on some changes to our service.",
    "Dear participants, Thank you for registering for our workshop next week."
]

let messageExamples = [
    "Hey Sarah, are we still on for lunch today?",
    "Hi! Just wanted to check in and see how you're doing",
    "Yo, did you see that game last night?",
    "Hey team, quick question about the project",
    "What's up? Want to grab coffee later?",
    "Thanks for the help earlier!",
    "Sure thing, I'll take care of that",
    "On my way, be there in 5 minutes",
    "Can you send me that file when you get a chance",
    "Sounds good to me!",
    "LOL that's hilarious",
    "Congrats on the new job!",
    "Miss you! Let's catch up soon",
    "Running a bit late, sorry",
    "Perfect timing, I was just about to ask you the same thing",
    "No worries, happens to everyone",
    "Awesome, thanks for letting me know",
    "Hey, have you heard back from them yet?",
    "That works for me, see you then",
    "Great idea! Let's do it"
]

let documentExamples = [
    "The quarterly financial report demonstrates significant growth across all market segments. Revenue increased by 23% compared to the previous quarter.",
    "Executive Summary: This document outlines the strategic initiatives for the upcoming fiscal year. Key priorities include market expansion and operational efficiency.",
    "The research methodology employed in this study utilized a mixed-methods approach combining quantitative surveys with qualitative interviews.",
    "The board of directors convened on October 15th to discuss the proposed merger and acquisition strategy.",
    "Analysis of the data reveals a strong correlation between customer satisfaction scores and retention rates.",
    "The implementation plan consists of three distinct phases executed over a twelve-month period.",
    "Findings from the market research indicate a growing demand for sustainable products among millennial consumers.",
    "The proposed budget allocation prioritizes investments in research and development while maintaining operational expenditures.",
    "The committee recommends adoption of the new policy framework effective January 1st of next year.",
    "Preliminary results suggest that the intervention significantly improved patient outcomes across multiple metrics.",
    "The comprehensive review examined all aspects of the current organizational structure and identified areas for improvement.",
    "Statistical analysis demonstrates a statistically significant difference between the control and experimental groups.",
    "The white paper presents a detailed examination of industry trends and their implications for future growth.",
    "Performance metrics indicate that the initiative exceeded its stated objectives in all key performance indicators.",
    "The strategic plan encompasses both short-term tactical goals and long-term visionary objectives.",
    "Regulatory compliance requirements mandate adherence to established protocols and documentation standards.",
    "The assessment framework evaluates competency across technical skills, leadership capabilities, and strategic thinking.",
    "The annual report provides stakeholders with transparent disclosure of financial performance and operational achievements.",
    "The literature review synthesizes existing research and identifies gaps in current understanding.",
    "Policy recommendations are grounded in evidence-based analysis of program effectiveness and cost-benefit considerations."
]

let socialExamples = [
    "Just shipped our new feature! Love seeing users respond",
    "Can't believe it's already Friday! Weekend vibes starting early",
    "Excited to announce I'm joining the team at TechCorp!",
    "Beautiful sunset tonight, had to share",
    "New blog post is live! Check it out and let me know what you think",
    "Grateful for this amazing community",
    "Quick poll: coffee or tea?",
    "Absolutely loving this new album on repeat",
    "Travel tip: always pack an extra charger",
    "Celebrating 1 year at the company today!",
    "Big news coming soon, stay tuned",
    "Throwback to last summer's adventure",
    "Monday motivation: you got this",
    "Currently reading this fantastic book, highly recommend",
    "Life update: moved to a new city and loving it so far",
    "Random thought: why do we park in driveways and drive on parkways",
    "Workout complete, feeling accomplished",
    "Anyone else completely obsessed with this show",
    "Just launched my side project, feedback welcome",
    "Thankful for amazing friends and family"
]

let codeExamples = [
    "function calculateTotal(items) { return items.reduce((sum, item) => sum + item.price, 0); }",
    "const API_URL = 'https://api.example.com'; fetch(API_URL).then(response => response.json());",
    "class UserManager { constructor() { this.users = []; } addUser(user) { this.users.push(user); } }",
    "if (user.isAuthenticated) { return <Dashboard />; } else { return <Login />; }",
    "import React from 'react'; import { useState } from 'react'; const [count, setCount] = useState(0);",
    "def process_data(data): return [item for item in data if item.is_valid()]",
    "async function fetchUserData(userId) { const response = await api.get(`/users/${userId}`); return response.data; }",
    "var result = array.filter(x => x > 10).map(x => x * 2).reduce((a, b) => a + b);",
    "struct Point { let x: Double; let y: Double; func distance(to other: Point) -> Double { return sqrt(pow(x - other.x, 2) + pow(y - other.y, 2)); } }",
    "SELECT users.name, orders.total FROM users JOIN orders ON users.id = orders.user_id WHERE orders.status = 'completed';",
    "try { await database.query(sql); } catch (error) { logger.error('Database error:', error); throw error; }",
    "export default function Component() { useEffect(() => { console.log('mounted'); return () => console.log('unmounted'); }, []); }",
    "public class Calculator { public int add(int a, int b) { return a + b; } }",
    "let numbers = [1, 2, 3, 4, 5]; let doubled = numbers.map { $0 * 2 };",
    "const handleClick = (event) => { event.preventDefault(); setIsOpen(!isOpen); };",
    "from typing import List, Optional; def find_user(user_id: int) -> Optional[User]: return db.query(User).filter(User.id == user_id).first()",
    "interface User { id: number; name: string; email: string; }",
    "for i in range(len(array)): if array[i] == target: return i; return -1;",
    "enum Status { case pending; case active; case completed; case failed; }",
    "const query = `INSERT INTO users (name, email) VALUES (?, ?)`, [name, email];"
]

let searchExamples = [
    "weather in San Francisco",
    "how to learn Swift programming",
    "best restaurants near me",
    "python list comprehension tutorial",
    "stock price AAPL",
    "convert 100 USD to EUR",
    "what time is it in Tokyo",
    "define cryptocurrency",
    "movie showtimes tonight",
    "directions to nearest coffee shop",
    "latest news technology",
    "who won the game yesterday",
    "calculate mortgage payment",
    "translate hello to Spanish",
    "find hotels in Paris",
    "recipe for chocolate cake",
    "flight status AA 123",
    "what is machine learning",
    "upcoming concerts in New York",
    "population of Canada"
]

// MARK: - CSV Generation

func generateCSV() {
    var rows: [String] = ["text,label"]

    // Add all examples
    for example in emailExamples {
        rows.append("\"\(example)\",email")
    }

    for example in messageExamples {
        rows.append("\"\(example)\",message")
    }

    for example in documentExamples {
        rows.append("\"\(example)\",document")
    }

    for example in socialExamples {
        rows.append("\"\(example)\",social")
    }

    for example in codeExamples {
        rows.append("\"\(example)\",code")
    }

    for example in searchExamples {
        rows.append("\"\(example)\",search")
    }

    let csv = rows.joined(separator: "\n")

    // Write to file
    let fileURL = URL(fileURLWithPath: "training_data.csv")
    do {
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)
        print("✅ Generated training_data.csv with \(rows.count - 1) examples")
        print("   - Email: \(emailExamples.count)")
        print("   - Message: \(messageExamples.count)")
        print("   - Document: \(documentExamples.count)")
        print("   - Social: \(socialExamples.count)")
        print("   - Code: \(codeExamples.count)")
        print("   - Search: \(searchExamples.count)")
    } catch {
        print("❌ Error writing CSV: \(error)")
    }
}

// Run
generateCSV()
