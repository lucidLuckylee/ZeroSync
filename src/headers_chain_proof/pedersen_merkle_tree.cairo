from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, HashBuiltin
from starkware.cairo.common.hash import hash2

func compute_merkle_root_pedersen{range_check_ptr, hash_ptr: HashBuiltin*}(
    leaves: felt*, leaves_len: felt
) -> felt {
    alloc_locals;

    // The trivial case is a tree with a single leaf
    if (leaves_len == 1) {
        return leaves[0];
    }

    // TODO: Figure out if this allows attackers to create wrong merkle trees
    // If the number of leaves is odd then set the last leaf to 0
    let (_, is_odd) = unsigned_div_rem(leaves_len, 2);
    if (is_odd == 1) {
        assert leaves[leaves_len] = 0;
    }

    // Compute the next generation of leaves one level higher up in the tree
    let (next_leaves) = alloc();
    let next_leaves_len = (leaves_len + is_odd) / 2;
    _compute_merkle_root_pedersen_loop(leaves, next_leaves, next_leaves_len);

    // Ascend in the tree and recurse on the next generation one step closer to the root
    return compute_merkle_root_pedersen(next_leaves, next_leaves_len);
}

// starting leaves contains first node of the merkle_path if necessary
// old_merkle_path[x] is zero if the node of the path is not required for recalculating level x
func append_merkle_tree_pedersen{range_check_ptr, hash_ptr: HashBuiltin*}(
    leaves: felt*, leaves_len: felt, merkle_path : felt *
) -> felt {
    alloc_locals;

    // The trivial case is a tree with a single leaf
    if (leaves_len == 1) {
        return leaves[0];
    }

    // TODO: Figure out if this allows attackers to create wrong merkle trees
    // If the number of leaves is odd then set the last leaf to 0
    let (_, is_odd) = unsigned_div_rem(leaves_len, 2);
    if (is_odd == 1) {
        assert leaves[leaves_len] = 0;
    }

    let (next_leaves) = alloc();
    let next_leaves_len = (leaves_len + is_odd) / 2;
    if (merkle_path[0] == 0) {
        // Compute the next generation of leaves one level higher up in the tree
        _compute_merkle_root_pedersen_loop(leaves, next_leaves, next_leaves_len);
        // Ascend in the tree and recurse on the next generation one step closer to the root
        return append_merkle_tree_pedersen(next_leaves, next_leaves_len, merkle_path + 1);
    } else {
        // Put the merkle_path entry for the next level into next_leaves
        assert next_leaves[0] = merkle_path[0];
        // Compute the next generation of leaves one level higher up in the tree
        // Account for the already filled position 0 in next_leaves
        _compute_merkle_root_pedersen_loop(leaves, next_leaves + 1, next_leaves_len);
        return append_merkle_tree_pedersen(next_leaves, next_leaves_len + 1, merkle_path + 1);
    }

}
// Compute the next generation of leaves by pairwise hashing
// the previous generation of leaves
func _compute_merkle_root_pedersen_loop{range_check_ptr, hash_ptr: HashBuiltin*}(
    prev_leaves: felt*, next_leaves: felt*, loop_counter
) {
    alloc_locals;

    // We loop until we've completed the next generation
    if (loop_counter == 0) {
        return ();
    }

    // Hash two prev_leaves to get one leaf of the next generation
    let (hash) = hash2(prev_leaves[0], prev_leaves[1]);
    assert next_leaves[0] = hash;
    // Continue this loop with the next two prev_leaves
    return _compute_merkle_root_pedersen_loop(
        prev_leaves + 2, next_leaves + 1, loop_counter - 1
    );
}



// NOTE: This function is used in a setting where the only proof we check is of the right most leaf.
// Therefore, we assume that every hash in the tree has the element as the right leave and the 
// merkle_path leaf as the left one.
func verify_merkle_path{hash_ptr: HashBuiltin*}(element, merkle_path: felt*, merkle_path_len, merkle_root) {
    if (merkle_path_len == 0) {
        return ();
    }

    if (merkle_path_len == 1) {
        let (root_hash) = hash2(merkle_path[0], element);
        assert root_hash = merkle_root; 
        return ();
    }

    let (new_element) = hash2(merkle_path[0], element);
    verify_merkle_path(new_element, merkle_path + 1, merkle_path_len - 1, merkle_root);

    return ();
}
