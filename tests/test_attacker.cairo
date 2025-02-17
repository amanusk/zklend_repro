use snforge_std::{CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare};
use starknet::{ContractAddress, contract_address_const, get_contract_address};
use zklend_repro::attacker::{IAttackerDispatcher, IAttackerDispatcherTrait};
use zklend_repro::interfaces::{IMarketDispatcher, IMarketDispatcherTrait};

fn setup() -> ContractAddress {
    let market_address: ContractAddress = contract_address_const::<
        0x4c0a5193d58f74fbace4b74dcf65481e734ed1714121bdc571da345540efa05,
    >();
    let attacker_class = declare("Attacker").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    market_address.serialize(ref calldata);

    let (contract_address, _) = attacker_class.deploy(@calldata).unwrap();
    contract_address
}
#[test]
#[fork("MAINNET_LATEST", block_number: 1143545)]
fn test_create_post() {
    let contract_address = setup();
    let attacker = IAttackerDispatcher { contract_address };
}
// #[test]
// fn test_create_comment() {
//     let contract_address = setup();
//     let social_post = IPostDispatcher { contract_address };
//
//     // Create parent post
//     let parent_id = social_post.create_post();
//
//     // Create comment
//     let comment_id = social_post.create_comment(parent_id);
//     assert!(comment_id == 2, "Comment should be ID 2");
//
//     // Verify comment data
//     let is_comment = social_post.is_comment(comment_id);
//     assert!(is_comment, "Should be a comment");
//
//     let parent_author = social_post.get_post_author(parent_id);
//     let comment_author = social_post.get_post_author(comment_id);
//     assert!(parent_author == comment_author, "Authors should match");
// }
//
// #[test]
// #[should_panic(expected: ('Parent post does not exist',))]
// fn test_create_comment_invalid_parent() {
//     let contract_address = setup();
//     let social_post = IPostDispatcher { contract_address };
//
//     social_post.create_comment(999); // Non-existent parent ID
// }
//
// #[test]
// fn test_like_post() {
//     let contract_address = setup();
//     let social_post = IPostDispatcher { contract_address };
//     let post_id = social_post.create_post();
//
//     // Switch to different user for liking
//     let liker: ContractAddress = contract_address_const::<456>();
//     cheat_caller_address(social_post.contract_address, liker, CheatSpan::TargetCalls(1));
//
//     social_post.like_post(post_id);
//
//     let likes = social_post.get_post_likes(post_id);
//     assert(likes == 1, 'Likes should increment');
// }
//
// #[test]
// #[should_panic(expected: ('Cannot like own post',))]
// fn test_like_own_post() {
//     let contract_address = setup();
//     let social_post = IPostDispatcher { contract_address };
//     let post_id = social_post.create_post();
//
//     // Try to like own post
//     social_post.like_post(post_id);
// }
//
// #[test]
// #[should_panic(expected: ('Already liked',))]
// fn test_double_like() {
//     let contract_address = setup();
//     let social_post = IPostDispatcher { contract_address };
//     let post_id = social_post.create_post();
//
//     let liker: ContractAddress = contract_address_const::<456>();
//     cheat_caller_address(social_post.contract_address, liker, CheatSpan::TargetCalls(2));
//
//     social_post.like_post(post_id);
//     social_post.like_post(post_id); // Second like should fail
// }
//
// #[test]
// fn test_multiple_likes() {
//     let contract_address = setup();
//     let social_post = IPostDispatcher { contract_address };
//     let post_id = social_post.create_post();
//
//     // First liker
//     let liker1: ContractAddress = contract_address_const::<111>();
//     cheat_caller_address(social_post.contract_address, liker1, CheatSpan::TargetCalls(1));
//     social_post.like_post(post_id);
//
//     // Second liker
//     let liker2: ContractAddress = contract_address_const::<222>();
//     cheat_caller_address(social_post.contract_address, liker2, CheatSpan::TargetCalls(1));
//     social_post.like_post(post_id);
//
//     let likes = social_post.get_post_likes(post_id);
//     assert(likes == 2, 'Should have 2 likes');
// }
//
// #[test]
// #[should_panic(expected: ('Post does not exist',))]
// fn test_invalid_post_access() {
//     let contract_address = setup();
//     let social_post = IPostDispatcher { contract_address }
//     social_post.get_post_author(999); // Non-existent post ID
// }
//


