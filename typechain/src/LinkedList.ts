/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumber,
  BigNumberish,
  BytesLike,
  CallOverrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import type { FunctionFragment, Result } from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type {
  TypedEventFilter,
  TypedEvent,
  TypedListener,
  OnEvent,
  PromiseOrValue,
} from "../common";

export interface LinkedListInterface extends utils.Interface {
  functions: {
    "getAdjacent(uint256,bool)": FunctionFragment;
    "getData(uint256)": FunctionFragment;
    "getNext(uint256)": FunctionFragment;
    "getNextNode(uint256)": FunctionFragment;
    "getPrev(uint256)": FunctionFragment;
    "getPreviousNode(uint256)": FunctionFragment;
    "head()": FunctionFragment;
    "inList(uint256)": FunctionFragment;
    "isInitialized()": FunctionFragment;
    "list(uint256,bool)": FunctionFragment;
    "size()": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "getAdjacent"
      | "getData"
      | "getNext"
      | "getNextNode"
      | "getPrev"
      | "getPreviousNode"
      | "head"
      | "inList"
      | "isInitialized"
      | "list"
      | "size"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "getAdjacent",
    values: [PromiseOrValue<BigNumberish>, PromiseOrValue<boolean>]
  ): string;
  encodeFunctionData(
    functionFragment: "getData",
    values: [PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "getNext",
    values: [PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "getNextNode",
    values: [PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "getPrev",
    values: [PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "getPreviousNode",
    values: [PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(functionFragment: "head", values?: undefined): string;
  encodeFunctionData(
    functionFragment: "inList",
    values: [PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "isInitialized",
    values?: undefined
  ): string;
  encodeFunctionData(
    functionFragment: "list",
    values: [PromiseOrValue<BigNumberish>, PromiseOrValue<boolean>]
  ): string;
  encodeFunctionData(functionFragment: "size", values?: undefined): string;

  decodeFunctionResult(
    functionFragment: "getAdjacent",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "getData", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "getNext", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "getNextNode",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "getPrev", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "getPreviousNode",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "head", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "inList", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "isInitialized",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "list", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "size", data: BytesLike): Result;

  events: {};
}

export interface LinkedList extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: LinkedListInterface;

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>;

  listeners<TEvent extends TypedEvent>(
    eventFilter?: TypedEventFilter<TEvent>
  ): Array<TypedListener<TEvent>>;
  listeners(eventName?: string): Array<Listener>;
  removeAllListeners<TEvent extends TypedEvent>(
    eventFilter: TypedEventFilter<TEvent>
  ): this;
  removeAllListeners(eventName?: string): this;
  off: OnEvent<this>;
  on: OnEvent<this>;
  once: OnEvent<this>;
  removeListener: OnEvent<this>;

  functions: {
    getAdjacent(
      _tokenId: PromiseOrValue<BigNumberish>,
      direction: PromiseOrValue<boolean>,
      overrides?: CallOverrides
    ): Promise<[boolean, BigNumber]>;

    getData(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<
      [boolean, BigNumber, BigNumber] & {
        exists: boolean;
        prev: BigNumber;
        next: BigNumber;
      }
    >;

    getNext(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<[boolean, BigNumber] & { exists: boolean; next: BigNumber }>;

    getNextNode(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<[boolean, BigNumber]>;

    getPrev(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<[boolean, BigNumber] & { exists: boolean; prev: BigNumber }>;

    getPreviousNode(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<[boolean, BigNumber]>;

    head(overrides?: CallOverrides): Promise<[BigNumber]>;

    inList(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<[boolean] & { exists: boolean }>;

    isInitialized(
      overrides?: CallOverrides
    ): Promise<[boolean] & { initialized: boolean }>;

    list(
      arg0: PromiseOrValue<BigNumberish>,
      arg1: PromiseOrValue<boolean>,
      overrides?: CallOverrides
    ): Promise<[BigNumber]>;

    size(overrides?: CallOverrides): Promise<[BigNumber]>;
  };

  getAdjacent(
    _tokenId: PromiseOrValue<BigNumberish>,
    direction: PromiseOrValue<boolean>,
    overrides?: CallOverrides
  ): Promise<[boolean, BigNumber]>;

  getData(
    _tokenId: PromiseOrValue<BigNumberish>,
    overrides?: CallOverrides
  ): Promise<
    [boolean, BigNumber, BigNumber] & {
      exists: boolean;
      prev: BigNumber;
      next: BigNumber;
    }
  >;

  getNext(
    _tokenId: PromiseOrValue<BigNumberish>,
    overrides?: CallOverrides
  ): Promise<[boolean, BigNumber] & { exists: boolean; next: BigNumber }>;

  getNextNode(
    _tokenId: PromiseOrValue<BigNumberish>,
    overrides?: CallOverrides
  ): Promise<[boolean, BigNumber]>;

  getPrev(
    _tokenId: PromiseOrValue<BigNumberish>,
    overrides?: CallOverrides
  ): Promise<[boolean, BigNumber] & { exists: boolean; prev: BigNumber }>;

  getPreviousNode(
    _tokenId: PromiseOrValue<BigNumberish>,
    overrides?: CallOverrides
  ): Promise<[boolean, BigNumber]>;

  head(overrides?: CallOverrides): Promise<BigNumber>;

  inList(
    _tokenId: PromiseOrValue<BigNumberish>,
    overrides?: CallOverrides
  ): Promise<boolean>;

  isInitialized(overrides?: CallOverrides): Promise<boolean>;

  list(
    arg0: PromiseOrValue<BigNumberish>,
    arg1: PromiseOrValue<boolean>,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  size(overrides?: CallOverrides): Promise<BigNumber>;

  callStatic: {
    getAdjacent(
      _tokenId: PromiseOrValue<BigNumberish>,
      direction: PromiseOrValue<boolean>,
      overrides?: CallOverrides
    ): Promise<[boolean, BigNumber]>;

    getData(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<
      [boolean, BigNumber, BigNumber] & {
        exists: boolean;
        prev: BigNumber;
        next: BigNumber;
      }
    >;

    getNext(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<[boolean, BigNumber] & { exists: boolean; next: BigNumber }>;

    getNextNode(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<[boolean, BigNumber]>;

    getPrev(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<[boolean, BigNumber] & { exists: boolean; prev: BigNumber }>;

    getPreviousNode(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<[boolean, BigNumber]>;

    head(overrides?: CallOverrides): Promise<BigNumber>;

    inList(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<boolean>;

    isInitialized(overrides?: CallOverrides): Promise<boolean>;

    list(
      arg0: PromiseOrValue<BigNumberish>,
      arg1: PromiseOrValue<boolean>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    size(overrides?: CallOverrides): Promise<BigNumber>;
  };

  filters: {};

  estimateGas: {
    getAdjacent(
      _tokenId: PromiseOrValue<BigNumberish>,
      direction: PromiseOrValue<boolean>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getData(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getNext(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getNextNode(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getPrev(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getPreviousNode(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    head(overrides?: CallOverrides): Promise<BigNumber>;

    inList(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    isInitialized(overrides?: CallOverrides): Promise<BigNumber>;

    list(
      arg0: PromiseOrValue<BigNumberish>,
      arg1: PromiseOrValue<boolean>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    size(overrides?: CallOverrides): Promise<BigNumber>;
  };

  populateTransaction: {
    getAdjacent(
      _tokenId: PromiseOrValue<BigNumberish>,
      direction: PromiseOrValue<boolean>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    getData(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    getNext(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    getNextNode(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    getPrev(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    getPreviousNode(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    head(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    inList(
      _tokenId: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    isInitialized(overrides?: CallOverrides): Promise<PopulatedTransaction>;

    list(
      arg0: PromiseOrValue<BigNumberish>,
      arg1: PromiseOrValue<boolean>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    size(overrides?: CallOverrides): Promise<PopulatedTransaction>;
  };
}