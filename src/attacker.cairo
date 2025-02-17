use starknet::ContractAddress;
use zklend_repro::interfaces::{IMarketDispatcher, IMarketDispatcherTrait};

#[starknet::interface]
pub trait IAttacker<TContractState> {
    fn get_lending_accumulator_for_token(self: @TContractState, token: ContractAddress) -> felt252;
    fn update_market_contract(ref self: TContractState, new_market_address: ContractAddress);
}

#[starknet::contract]
pub mod Attacker {
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::{IMarketDispatcher, IMarketDispatcherTrait};

    #[storage]
    struct Storage {
        market_contract: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, market_address: ContractAddress) {
        self.market_contract.write(market_address);
    }

    #[abi(embed_v0)]
    impl AttackerImpl of super::IAttacker<ContractState> {
        fn get_lending_accumulator_for_token(
            self: @ContractState, token: ContractAddress,
        ) -> felt252 {
            let market = IMarketDispatcher { contract_address: self.market_contract.read() };
            market.get_lending_accumulator(token)
        }

        fn update_market_contract(ref self: ContractState, new_market_address: ContractAddress) {
            self.market_contract.write(new_market_address);
        }
    }
}
