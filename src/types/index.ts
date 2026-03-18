export type Direction = 'UP' | 'DOWN' | 'LEFT' | 'RIGHT';

export interface Position {
  x: number;
  y: number;
}

export interface GameState {
  snake: Position[];
  food: Position;
  direction: Direction;
  nextDirection: Direction; // buffer for next move to prevent rapid key presses causing self-collision
  score: number;
  highScore: number;
  status: 'IDLE' | 'PLAYING' | 'PAUSED' | 'GAME_OVER';
  speed: number;
}

export const GRID_SIZE = 20;
export const INITIAL_SPEED = 150;
export const MIN_SPEED = 50;
