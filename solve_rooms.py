from collections import deque
import operator
from typing import Callable, Mapping

ROOMS = [
    ['*', '8', '-', '1'],
    ['4', '*', '11', '*'],
    ['+', '4', '-', '18'],
    ['22', '-', '9', '*'],
]

START = (0, 3)
END = (3, 0)
END_VAL = 30

op_to_f: Mapping[str, Callable[[int, int], int]] = {
    '+': operator.add,
    '-': operator.sub,
    '*': operator.mul,
}

def main():
    q = deque()
    q.append((START[0], START[1], operator.add, 0, []))

    while len(q) > 0:
        x, y, op_f, val, path = q.popleft()
        if x == START[0] and y == START[1] and len(path) > 0:
            continue

        room = ROOMS[y][x]
        if op_f is None:
            op_f = op_to_f[room]
        else:
            room_num = int(room)
            val = op_f(val, room_num)
            op_f = None
        path = list(path)
        path.append(room)

        if x == END[0] and y == END[1] and val == END_VAL:
            print(path)
            break

        if x > 0:
            q.append((x-1, y, op_f, val, path))
        if y > 0:
            q.append((x, y-1, op_f, val, path))
        if x < 3:
            q.append((x+1, y, op_f, val, path))
        if y < 3:
            q.append((x, y+1, op_f, val, path))

if __name__ == "__main__":
    main()
