import { useState } from "react";

export default function App() {
    const [numbersInput, setNumbersInput] = useState("");
    const [windowSize, setWindowSize] = useState(3);
    const [maxSum, setMaxSum] = useState<number | null>(null);
    const [error, setError] = useState<string | null>(null);

    const handleSubmit = async () => {
        try {
            const numbers = numbersInput
                .split(",")
                .map((n) => parseInt(n.trim(), 10))
                .filter((n) => !isNaN(n));

            const params = new URLSearchParams();
            numbers.forEach((n) => params.append("numbers", n.toString()));
            params.append("windowSize", windowSize.toString());

            // const response = await fetch(`/api/sliding-window?${params.toString()}`);
            const apiBase = import.meta.env.VITE_API_BASE_URL || "";
            const response = await fetch(`${apiBase}/api/sliding-window?${params.toString()}`);

            if (!response.ok) {
                throw new Error("Server responded with an error");
            }

            const data = await response.json();
            setMaxSum(data.maxSum);
            setError(null);
        } catch (err: any) {
            setError(err.message || "An unknown error occurred");
        }
    };

    return (
        <div className="max-w-xl mx-auto p-6 space-y-4">
            <h1 className="text-2xl font-bold text-center">Sliding Window Max Sum</h1>
            <div className="space-y-2">
                <input
                    type="text"
                    className="w-full border p-2 rounded"
                    placeholder="Enter numbers separated by commas (e.g., 1,2,3,4)"
                    value={numbersInput}
                    onChange={(e) => setNumbersInput(e.target.value)}
                />
                <input
                    type="number"
                    className="w-full border p-2 rounded"
                    placeholder="Window size"
                    value={windowSize}
                    onChange={(e) => setWindowSize(parseInt(e.target.value, 10))}
                />
                <button
                    className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
                    onClick={handleSubmit}
                >
                    Calculate
                </button>
            </div>
            {maxSum !== null && (
                <p className="text-green-700 font-semibold">Max Sum: {maxSum}</p>
            )}
            {error && <p className="text-red-600 font-medium">Error: {error}</p>}
        </div>
    );
}
