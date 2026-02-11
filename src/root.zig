const std = @import("std");
const Game = struct {
    const Piece_types = enum { king, queen, rook, bishop, knight, pawn };

    const Color = enum { white, black };
    const Piece = struct {
        type: Piece_types,
        posy: u8,
        posx: u8,
        color: Color,
    };

    const Board = struct {
        pieces: []const Piece,
    };

    const Move = struct {
        from_x: u8,
        from_y: u8,
        to_x: u8,
        to_y: u8,
        piece_type: Piece_types,
        capture: bool,
    };

    board: Board,
    moves: std.ArrayList(Move),
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) !*Game {
        const pieces = try alloc.dupe(
            Piece,
            &[_]Piece{
                .{ .type = .king, .posy = 0, .posx = 4, .color = .white },
                .{ .type = .queen, .posy = 0, .posx = 3, .color = .white },
                .{ .type = .queen, .posy = 0, .posx = 3, .color = .white },
                .{ .type = .rook, .posy = 0, .posx = 0, .color = .white },
                .{ .type = .rook, .posy = 0, .posx = 7, .color = .white },
                .{ .type = .bishop, .posy = 0, .posx = 2, .color = .white },
                .{ .type = .bishop, .posy = 0, .posx = 5, .color = .white },
                .{ .type = .knight, .posy = 0, .posx = 1, .color = .white },
                .{ .type = .knight, .posy = 0, .posx = 6, .color = .white },
                .{ .type = .king, .posy = 7, .posx = 4, .color = .black },
                .{ .type = .queen, .posy = 7, .posx = 3, .color = .black },
                .{ .type = .rook, .posy = 7, .posx = 0, .color = .black },
                .{ .type = .rook, .posy = 7, .posx = 7, .color = .black },
                .{ .type = .bishop, .posy = 7, .posx = 2, .color = .black },
                .{ .type = .bishop, .posy = 7, .posx = 5, .color = .black },
                .{ .type = .knight, .posy = 7, .posx = 1, .color = .black },
                .{ .type = .knight, .posy = 7, .posx = 6, .color = .black },
            } ++ comptime blk: {
                var pawns_black: [8]Piece = undefined;
                for (0..8) |i| {
                    pawns_black[i] = .{ .type = .pawn, .posy = 6, .posx = @intCast(i), .color = .black };
                }
                var pawns_white: [8]Piece = undefined;
                for (0..8) |i| {
                    pawns_white[i] = .{ .type = .pawn, .posy = 1, .posx = @intCast(i), .color = .white };
                }
                break :blk pawns_white ++ pawns_black;
            },
        );

        const moves = std.ArrayList(Move).initCapacity(alloc, 256) catch unreachable;

        const game = alloc.create(Game) catch unreachable;
        game.* = Game{
            .alloc = alloc,
            .board = Board{
                .pieces = pieces,
            },
            .moves = moves.toOwnedSlice(),
        };
        return game;
    }

    pub fn deinit(self: *Game) void {
        self.alloc.free(self.board.pieces);
        self.alloc.free(self.moves);
        self.alloc.destroy(self);
    }

    fn get_piece(self: *Game, x: u8, y: u8) ?Piece {
        for (self.board.pieces) |piece| {
            if (piece.posx == x and piece.posy == y) return piece;
        }
        return null;
    }

    fn available_moves_king(self: *const Game, piece: Piece) ![]Move {
        var moves = try std.ArrayList(Move).initCapacity(self.alloc, 8);
        const deltas = [_]i8{ -1, 0, 1 };
        for (deltas) |i| {
            for (deltas) |j| {
                const nx = @as(i8, piece.posx) + i;
                const ny = @as(i8, piece.posy) + j;
                if (nx < 0 or nx > 7 or ny < 0 or ny > 7) continue;

                const tx: u8 = @intCast(nx);
                const ty: u8 = @intCast(ny);
                const has_piece = if (get_piece(self, tx, ty)) |p|
                    if (p.color == piece.color) continue else true
                else
                    false;
                try moves.append(.{
                    .from_x = piece.posx,
                    .from_y = piece.posy,
                    .to_x = piece.posx + i,
                    .to_y = piece.posy + j,
                    .capture = has_piece,
                });
            }
        }
        return moves.toOwnedSlice(self.alloc) catch unreachable;
    }

    fn available_moves_pawn(self: *const Game, piece: Piece) ![]Move {
        var moves = try std.ArrayList(Move).initCapacity(self.alloc, 8);
        if (piece.color == .white and piece.posy == 1 and !self.has_piece(piece.posx, 2) and !self.has_piece(piece.posx, 3))
            moves.append(.{
                .from_x = piece.posx,
                .from_y = piece.posy,
                .to_x = piece.posx,
                .to_y = piece.posy + 2,
                .capture = false,
            });
        if (piece.color == .black and piece.posy == 6 and !self.has_piece(piece.posx, 5) and !self.has_piece(piece.posx, 4))
            moves.append(.{
                .from_x = piece.posx,
                .from_y = piece.posy,
                .to_x = piece.posx,
                .to_y = piece.posy - 2,
                .capture = false,
            });

        if (piece.color == .white and piece.posy < 7 and !self.has_piece(piece.posx, piece.posy + 1))
            moves.append(.{
                .from_x = piece.posx,
                .from_y = piece.posy,
                .to_x = piece.posx,
                .to_y = piece.posy + 1,
                .capture = false,
            });

        if (piece.color == .black and piece.posy > 0 and !self.has_piece(piece.posx, piece.posy - 1))
            moves.append(.{
                .from_x = piece.posx,
                .from_y = piece.posy,
                .to_x = piece.posx,
                .to_y = piece.posy - 1,
                .capture = false,
            });

        if (self.moves.getLastOrNull()) |last| {
            if (last.piece_type == .pawn and last.to_y == piece.posy and @abs(last.from_y - last.to_y) == 2) {
                if (last.to_x == piece.posx - 1)
                    moves.append(.{
                        .from_x = piece.posx,
                        .from_y = piece.posy + 1,
                        .to_x = piece.posx - 1,
                        .to_y = piece.posy,
                        .capture = false,
                    });
                if (last.to_x == piece.posx + 1)
                    moves.append(.{
                        .from_x = piece.posx,
                        .from_y = piece.posy + 1,
                        .to_x = piece.posx + 1,
                        .to_y = piece.posy,
                        .capture = false,
                    });
            }
        }

        return moves.toOwnedSlice(self.alloc) catch unreachable;
    }

    fn available_moves(self: *const Game, piece: Piece) ![]Move {
        var moves = try std.ArrayList(Move).initCapacity(self.alloc, 32);
        switch (piece.type) {
            .king => {
                moves.appendSlice(self.alloc, self.available_moves_king(piece));
            },
            .pawn => {
                moves.appendSlice(self.alloc, self.available_moves_pawn(piece));
            },
        }
        return moves.toOwnedSlice() catch unreachable;
    }
};
