import heapq
import random
import time

def dijkstra(graph, start):
    distances = {node: float('inf') for node in graph}
    distances[start] = 0
    pq = [(0, start)]
    while pq:
        current_dist, current_node = heapq.heappop(pq)
        if current_dist > distances[current_node]:
            continue
        for neighbor, weight in graph[current_node].items():
            distance = current_dist + weight
            if distance < distances[neighbor]:
                distances[neighbor] = distance
                heapq.heappush(pq, (distance, neighbor))
    return distances

def generate_graph(n):
    graph = {i: {} for i in range(n)}
    for i in range(n):
        for j in range(random.randint(1, 10)):
            neighbor = random.randint(0, n - 1)
            weight = random.randint(1, 100)
            graph[i][neighbor] = weight
    return graph

iteration = 0
while True:
    n = 1000
    graph = generate_graph(n)
    result = dijkstra(graph, 0)
    iteration += 1
    print(f"Iteration {iteration} — plus court chemin depuis 0 : {min(result.values()):.0f}")
    time.sleep(0.1)